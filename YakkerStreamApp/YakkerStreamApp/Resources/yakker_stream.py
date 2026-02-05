#!/usr/bin/env python3
"""
Simple YakkerTech data streamer.

- Connects to YakkerTech websocket
- Tracks the most recent readings for each event (ignores invalid duplicates)
- Serves a small HTTP page on localhost showing key metrics in real time
"""

import argparse
import asyncio
import inspect
import json
import logging
import os
import re
import signal
import sys
import time
from typing import Awaitable, Callable, Dict, List, Optional, TypedDict, Union

from aiohttp import ClientConnectorError, ClientSession, WSMsgType, web

DEFAULT_WS_URL = os.getenv(
    "YAKKER_WS_URL", ""
)
DEFAULT_AUTH_RAW = os.getenv(
    "YAKKER_AUTH_HEADER", ""
)
DEFAULT_PORT = int(os.getenv("YAKKER_PORT", "8000"))
POLL_INTERVAL_SECONDS = float(os.getenv("YAKKER_POLL_INTERVAL", "1.0"))
ZONE_SPEED_KEY = "ZoneSpeedMPH"
REL_SPEED_KEY = "RelSpeedMPH"
PITCH_VELOCITY_KEYS = (ZONE_SPEED_KEY, REL_SPEED_KEY)
SPIN_RATE_KEY = "SpinRateRPM"
PITCH_METRIC_KEYS = PITCH_VELOCITY_KEYS + (SPIN_RATE_KEY,)
# Yakker merges pitch + hit observations; catcher throwbacks surface as a single contributing event,
# so require at least two event IDs (pitch + hit) when no pitch metrics accompany hit data.
MIN_CONTRIBUTING_EVENTS_FOR_HIT = 2
THROWBACK_MAX_EXIT_VELO = 60.0
THROWBACK_MIN_ANGLE_DEG = 10.0
THROWBACK_MAX_ANGLE_DEG = 20.0

PayloadHook = Callable[[dict], Union[Awaitable[None], None]]


def _extract_auth_value(raw_header: str) -> Optional[str]:
    if not raw_header:
        return None
    if raw_header.lower().startswith("authorization:"):
        return raw_header.split(":", 1)[1].strip()
    return raw_header.strip()


def _is_valid(value: Optional[float]) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        lowered = value.lower()
        if lowered in {"n/a", "na", "nan"}:
            return False
    try:
        float(value)
    except (TypeError, ValueError):
        return False
    return True


def _looks_like_throwback(hit_data: dict) -> bool:
    """Return True when the hit profile matches a soft throwback to the mound."""
    exit_velocity = hit_data.get("ExitSpeedMPH")
    launch_angle = hit_data.get("AngleDegrees")
    if not (_is_valid(exit_velocity) and _is_valid(launch_angle)):
        return False
    exit_velocity = float(exit_velocity)
    launch_angle = float(launch_angle)
    return (
        exit_velocity < THROWBACK_MAX_EXIT_VELO
        and THROWBACK_MIN_ANGLE_DEG <= launch_angle <= THROWBACK_MAX_ANGLE_DEG
    )


def _is_true_hit(hit_data: dict, pitch_data: dict, contributing_events: List[str]) -> bool:
    """
    Treat hits as valid when they include trustworthy bat metrics, while filtering out
    short throwbacks that Yakker reports as hit-only events.
    """
    if not hit_data:
        return False
    if _looks_like_throwback(hit_data):
        return False

    if _is_valid(hit_data.get("ExitSpeedMPH")):
        return True

    has_valid_pitch_metrics = any(
        _is_valid(pitch_data.get(key)) for key in PITCH_METRIC_KEYS
    )
    if has_valid_pitch_metrics:
        return True
    return len(contributing_events) >= MIN_CONTRIBUTING_EVENTS_FOR_HIT


async def _dispatch_payload_hooks(
    payload_hooks: Optional[List[PayloadHook]], payload: dict
) -> None:
    if not payload_hooks:
        return
    for hook in payload_hooks:
        try:
            result = hook(payload)
            if inspect.isawaitable(result):
                await result
        except Exception as exc:
            # Silently ignore payload hook failures
            pass


class MetricAggregator:
    TRACKED_METRICS = (
        "exit_velocity_mph",
        "launch_angle_deg",
        "pitch_velocity_mph",
        "spin_rate_rpm",
        "hit_distance_ft",
        "hangtime_sec",
    )
    STALE_TIMEOUT_SECONDS = 10
    ROLLING_WINDOW_SECONDS = 1.0

    class MetricEntry(TypedDict):
        value: float
        event_id: str
        updated_at: float
    
    class MetricSample(TypedDict):
        value: float
        timestamp: float

    def __init__(self) -> None:
        self.events: Dict[str, Dict[str, Optional[float]]] = {}
        self.latest_event_id: Optional[str] = None
        self.last_update_ts: Optional[float] = None
        self.latest_metrics: Dict[str, "MetricAggregator.MetricEntry"] = {}
        # Rolling buffer for 1-second recency filtering
        self.rolling_buffer: Dict[str, List["MetricAggregator.MetricSample"]] = {
            metric: [] for metric in self.TRACKED_METRICS
        }
        self._lock = asyncio.Lock()

    async def add_measurement(
        self,
        event_id: Optional[str],
        exit_velocity: Optional[float],
        launch_angle: Optional[float],
        pitch_velocity: Optional[float],
        spin_rate: Optional[float],
        hit_distance: Optional[float] = None,
        hangtime: Optional[float] = None,
    ) -> Dict[str, Optional[float]]:
        event_key = event_id or f"event-{int(time.time() * 1000)}"
        now = time.time()
        async with self._lock:
            bucket = self.events.setdefault(
                event_key,
                {
                    "exit_velocity_mph": None,
                    "launch_angle_deg": None,
                    "pitch_velocity_mph": None,
                    "spin_rate_rpm": None,
                    "hit_distance_ft": None,
                    "hangtime_sec": None,
                },
            )
            # Store latest valid reading per metric for this event
            for key, value in {
                "exit_velocity_mph": exit_velocity,
                "launch_angle_deg": launch_angle,
                "pitch_velocity_mph": pitch_velocity,
                "spin_rate_rpm": spin_rate,
                "hit_distance_ft": hit_distance,
                "hangtime_sec": hangtime,
            }.items():
                if _is_valid(value):
                    val = float(value)
                    bucket[key] = val
                    # Track latest sample for short-term recency filtering
                    if val != 0:
                        self.rolling_buffer[key].append({
                            "value": val,
                            "timestamp": now
                        })

            self.latest_event_id = event_key
            self.last_update_ts = now
            summary = self._summary_for(event_key, bucket)
            self._update_latest_metrics(summary)
            self._cleanup_rolling_buffer(now)
            return self._current_summary(now)

    async def latest_summary(self) -> Optional[Dict[str, Optional[float]]]:
        async with self._lock:
            if not self.last_update_ts or not self.latest_event_id:
                return None
            now = time.time()
            self._purge_stale_metrics(now)
            self._cleanup_rolling_buffer(now)
            if now - self.last_update_ts > self.STALE_TIMEOUT_SECONDS:
                return None
            return self._current_summary(now)
    
    def _cleanup_rolling_buffer(self, now: float) -> None:
        """Remove samples older than ROLLING_WINDOW_SECONDS from rolling buffer."""
        cutoff = now - self.ROLLING_WINDOW_SECONDS
        for metric in self.TRACKED_METRICS:
            self.rolling_buffer[metric] = [
                sample for sample in self.rolling_buffer[metric]
                if sample["timestamp"] > cutoff
            ]
    
    def _get_recent_value(self, metric: str) -> Optional[float]:
        """Return the most recent non-zero sample within the rolling window."""
        samples = self.rolling_buffer.get(metric, [])
        if not samples:
            return None
        return samples[-1]["value"]
    
    async def get_rolling_summary(self) -> Dict[str, Optional[float]]:
        """Get summary using 1-second rolling averages."""
        async with self._lock:
            now = time.time()
            self._cleanup_rolling_buffer(now)
            return {
                "event_id": self.latest_event_id,
                "exit_velocity_mph": self._get_recent_value("exit_velocity_mph"),
                "launch_angle_deg": self._get_recent_value("launch_angle_deg"),
                "pitch_velocity_mph": self._get_recent_value("pitch_velocity_mph"),
                "spin_rate_rpm": self._get_recent_value("spin_rate_rpm"),
                "hit_distance_ft": self._get_recent_value("hit_distance_ft"),
                "hangtime_sec": self._get_recent_value("hangtime_sec"),
                "updated_at": now,
            }


    def _summary_for(
        self, event_id: str, bucket: Dict[str, Optional[float]]
    ) -> Dict[str, Optional[float]]:
        def _latest(value: Optional[float]) -> Optional[float]:
            return float(value) if value is not None else None

        return {
            "event_id": event_id,
            "exit_velocity_mph": _latest(bucket["exit_velocity_mph"]),
            "launch_angle_deg": _latest(bucket["launch_angle_deg"]),
            "pitch_velocity_mph": _latest(bucket["pitch_velocity_mph"]),
            "spin_rate_rpm": _latest(bucket["spin_rate_rpm"]),
            "hit_distance_ft": _latest(bucket["hit_distance_ft"]),
            "hangtime_sec": _latest(bucket["hangtime_sec"]),
            "updated_at": self.last_update_ts,
        }

    def _update_latest_metrics(self, summary: Dict[str, Optional[float]]) -> None:
        event_id = summary.get("event_id")
        updated_at = summary.get("updated_at")
        if event_id is None or updated_at is None:
            return

        for key in self.TRACKED_METRICS:
            value = summary.get(key)
            if value is not None:
                self.latest_metrics[key] = {
                    "value": float(value),
                    "event_id": str(event_id),
                    "updated_at": float(updated_at),
                }

    def _current_summary(self, now: float) -> Dict[str, Optional[float]]:
        def _latest_value(metric: str) -> Optional[float]:
            info = self.latest_metrics.get(metric)
            if not info:
                return None
            updated_at = info.get("updated_at")
            if self._is_stale(updated_at, now):
                return None
            return info.get("value")

        return {
            "event_id": self.latest_event_id,
            "exit_velocity_mph": _latest_value("exit_velocity_mph"),
            "launch_angle_deg": _latest_value("launch_angle_deg"),
            "pitch_velocity_mph": _latest_value("pitch_velocity_mph"),
            "spin_rate_rpm": _latest_value("spin_rate_rpm"),
            "hit_distance_ft": _latest_value("hit_distance_ft"),
            "hangtime_sec": _latest_value("hangtime_sec"),
            "updated_at": self.last_update_ts,
        }

    def _purge_stale_metrics(self, now: float) -> None:
        self.latest_metrics = {
            key: info
            for key, info in self.latest_metrics.items()
            if not self._is_stale(info.get("updated_at"), now)
        }

    def _is_stale(self, updated_at: Optional[float], now: float) -> bool:
        return updated_at is None or now - updated_at > self.STALE_TIMEOUT_SECONDS


async def process_payload(
    payload: dict,
    aggregator: MetricAggregator,
    *,
    echo_console: bool = True,
) -> Optional[Dict[str, Optional[float]]]:
    event_id = payload.get("event_uuid") or payload.get("eventId")
    pitch_data = payload.get("pitch_data") or {}
    hit_data = payload.get("hit_data") or {}
    contributing_events = payload.get("contributing_events") or []

    pitch_velocity = pitch_data.get(ZONE_SPEED_KEY) or pitch_data.get(REL_SPEED_KEY)
    spin_rate = pitch_data.get(SPIN_RATE_KEY)

    include_hit = _is_true_hit(hit_data, pitch_data, contributing_events)
    exit_velocity = hit_data.get("ExitSpeedMPH") if include_hit else None
    launch_angle = hit_data.get("AngleDegrees") if include_hit else None
    hit_distance = hit_data.get("DistanceFeet") if include_hit else None
    hangtime = hit_data.get("HangTimeSeconds") if include_hit else None

    summary = await aggregator.add_measurement(
        event_id,
        exit_velocity=exit_velocity,
        launch_angle=launch_angle,
        pitch_velocity=pitch_velocity,
        spin_rate=spin_rate,
        hit_distance=hit_distance,
        hangtime=hangtime,
    )
    if echo_console and summary:
        pitch_display = _format_console_metric(summary.get("pitch_velocity_mph"), 1)
        spin_display = _format_console_metric(summary.get("spin_rate_rpm"), 0)
        exit_display = _format_console_metric(summary.get("exit_velocity_mph"), 1)
        launch_display = _format_console_metric(summary.get("launch_angle_deg"), 1)
        distance_display = _format_console_metric(summary.get("hit_distance_ft"), 0)
        hangtime_display = _format_console_metric(summary.get("hangtime_sec"), 1)
        
        # Use print with sys.stderr to output formatted metrics without timestamp prefixes
        # Truncate event ID to last 6 characters for cleaner display
        event_id_short = summary['event_id'][-6:] if summary['event_id'] else "N/A"
        event_output = (
            f"  -----------------------------\n"
            f"Event {event_id_short}\n"
            f"- Pitch Velo: {pitch_display} mph\n"
            f"- Spin: {spin_display} rpm\n"
            f"- Exit Velo: {exit_display} mph\n"
            f"- Launch: {launch_display}°\n"
            f"- Distance: {distance_display} ft\n"
            f"- Hangtime: {hangtime_display} s\n"
        )
        print(event_output, file=sys.stderr, flush=True)
    return summary


class YakkerStreamer:
    def __init__(
        self,
        ws_url: str,
        auth_value: Optional[str],
        aggregator: MetricAggregator,
        status: Dict[str, str],
        *,
        echo_console: bool = True,
        payload_hooks: Optional[List[PayloadHook]] = None,
    ) -> None:
        self.ws_url = ws_url
        self.auth_value = auth_value
        self.aggregator = aggregator
        self.echo_console = echo_console
        self.status = status
        self.payload_hooks = payload_hooks or []

    async def run(self) -> None:
        headers = {}
        if self.auth_value:
            headers["Authorization"] = self.auth_value

        async with ClientSession() as session:
            while True:
                try:
                    self.status["connection"] = "connecting"
                    print("⚙️  Connecting to Yakker data feed...", file=sys.stderr, flush=True)
                    async with session.ws_connect(
                        self.ws_url, headers=headers, heartbeat=30
                    ) as websocket:
                        self.status["connection"] = "connected"
                        print("✅ Connected to YakkerTech websocket", file=sys.stderr, flush=True)
                        async for message in websocket:
                            if message.type == WSMsgType.TEXT:
                                try:
                                    payload = json.loads(message.data)
                                    await _dispatch_payload_hooks(
                                        self.payload_hooks, payload
                                    )
                                    await process_payload(
                                        payload,
                                        self.aggregator,
                                        echo_console=self.echo_console,
                                    )
                                except json.JSONDecodeError as exc:
                                    print(f"⚠️  Bad payload: {exc}", file=sys.stderr, flush=True)
                            elif message.type == WSMsgType.ERROR:
                                print(f"❌ Websocket error: {message.data}", file=sys.stderr, flush=True)
                                break
                            elif message.type == WSMsgType.CLOSED:
                                break
                except ClientConnectorError as exc:
                    self.status["connection"] = "disconnected"
                    print(f"⚠️  Cannot connect to YakkerTech websocket: {exc}", file=sys.stderr, flush=True)
                    await asyncio.sleep(3)
                    continue
                except Exception as exc:
                    self.status["connection"] = "disconnected"
                    print(f"⚠️  Websocket interrupted: {exc}", file=sys.stderr, flush=True)
                    await asyncio.sleep(3)
                    continue


async def demo_feed(
    aggregator: MetricAggregator,
    status: Dict[str, str],
    *,
    echo_console: bool = True,
    payload_hooks: Optional[List[PayloadHook]] = None,
) -> None:
    status["connection"] = "demo"
    samples = [
        {
            "event_uuid": "demo-001",
            "pitch_data": {"ZoneSpeedMPH": 44.7, "SpinRateRPM": 1031.4},
            "hit_data": {"ExitSpeedMPH": 87.9, "AngleDegrees": 30.3, "DistanceFeet": 287.0, "HangTimeSeconds": 3.58},
        },
        {
            "event_uuid": "demo-001",
            "pitch_data": {"ZoneSpeedMPH": 44.8, "SpinRateRPM": 1073.3},
            "hit_data": {"ExitSpeedMPH": 87.7, "AngleDegrees": 30.3, "DistanceFeet": 287.0, "HangTimeSeconds": 3.58},
        },
        {
            "event_uuid": "demo-002",
            "pitch_data": {"ZoneSpeedMPH": 45.8, "SpinRateRPM": 1123.6},
            "hit_data": {"ExitSpeedMPH": 95.9, "AngleDegrees": 21.1, "DistanceFeet": 321.8, "HangTimeSeconds": 3.59},
        },
    ]
    while True:
        for sample in samples:
            await _dispatch_payload_hooks(payload_hooks, sample)
            await process_payload(sample, aggregator, echo_console=echo_console)
            await asyncio.sleep(POLL_INTERVAL_SECONDS)


async def periodic_updater(aggregator: MetricAggregator) -> None:
    """Periodically clean up rolling buffer to ensure fresh averages."""
    while True:
        await asyncio.sleep(1.0)  # Update every second
        try:
            # This triggers cleanup of old samples
            await aggregator.get_rolling_summary()
        except Exception as exc:
            print(f"⚠️  Error in periodic updater: {exc}", file=sys.stderr, flush=True)


async def update_livedata_xml(aggregator: MetricAggregator) -> None:
    """Update livedata.xml file every second with current Yakker data."""
    # Get the directory where the script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))
    template_path = os.path.join(script_dir, "livedata.xml.template")
    livedata_path = os.path.join(script_dir, "livedata.xml")
    
    # Read template once at startup
    if not os.path.exists(template_path):
        print(f"❌ Template file not found: {template_path}", file=sys.stderr, flush=True)
        return
    
    with open(template_path, 'r', encoding='utf-8') as f:
        template_content = f.read()
    
    print("✅ Loaded livedata.xml template", file=sys.stderr, flush=True)
    
    while True:
        await asyncio.sleep(1.0)  # Update every second
        try:
            # Get current summary (uses 10-second stale timeout, not 1-second rolling)
            summary = await aggregator.latest_summary()
            
            # Format metrics for XML (use placeholders if None or 0)
            exit_velo = _format_metric(summary.get("exit_velocity_mph") if summary else None, 1)
            launch_angle = _format_metric(summary.get("launch_angle_deg") if summary else None, 1)
            spin_rate = _format_metric(
                summary.get("spin_rate_rpm") if summary else None,
                0,
                empty_placeholder="---- ",
            )
            pitch_velo = _format_metric(summary.get("pitch_velocity_mph") if summary else None, 1)
            hit_distance = _format_metric(summary.get("hit_distance_ft") if summary else None, 0)
            hangtime = _format_metric(summary.get("hangtime_sec") if summary else None, 1)
            
            # Replace the XXX placeholders with actual data
            xml_content = re.sub(r'XXX-ExitVelo-XXX', exit_velo, template_content)
            xml_content = re.sub(r'XXX-LaunchAngle-XXX', launch_angle, xml_content)
            xml_content = re.sub(r'XXX-SpinRate-XXX', spin_rate, xml_content)
            xml_content = re.sub(r'XXX-PitchVelo-XXX', pitch_velo, xml_content)
            xml_content = re.sub(r'XXX-HitDistance-XXX', hit_distance, xml_content)
            xml_content = re.sub(r'XXX-Hangtime-XXX', hangtime, xml_content)
            
            # Write the updated content to livedata.xml
            with open(livedata_path, 'w', encoding='utf-8') as f:
                f.write(xml_content)
                
            # Silently update - no need to log every update
            pass
        except Exception as exc:
            print(f"⚠️  Error updating livedata.xml: {exc}", file=sys.stderr, flush=True)


def _format_metric(
    value: Optional[float], decimals: int, empty_placeholder: str = "-- "
) -> str:
    """Format a metric value for ProScoreboard, showing placeholder for 0 or None."""
    if value is None or value == 0:
        return empty_placeholder
    return f"{value:.{decimals}f}"


def _format_console_metric(value: Optional[float], decimals: int) -> str:
    """Format metric for console logging, showing em dash when missing."""
    if value is None:
        return "—"
    return f"{value:.{decimals}f}"


def _get_formatted_metrics(summary: Optional[Dict[str, Optional[float]]]) -> Dict[str, str]:
    """Extract and format metrics from summary for ProScoreboard output."""
    exit_velo = _format_metric(summary.get("exit_velocity_mph") if summary else None, 1)
    launch_angle = _format_metric(summary.get("launch_angle_deg") if summary else None, 1)
    spin_rate = _format_metric(
        summary.get("spin_rate_rpm") if summary else None,
        0,
        empty_placeholder="---- ",
    )
    pitch_velo = _format_metric(summary.get("pitch_velocity_mph") if summary else None, 1)
    hit_distance = _format_metric(summary.get("hit_distance_ft") if summary else None, 0)
    hangtime = _format_metric(summary.get("hangtime_sec") if summary else None, 1)
    
    return {
        "sportMode": "Custom",
        "ExitVelo": exit_velo,
        "LaunchAngle": launch_angle,
        "SpinRate": spin_rate,
        "PitchVelo": pitch_velo,
        "HitDistance": hit_distance,
        "Hangtime": hangtime
    }


def build_app(
    aggregator: MetricAggregator, status: Dict[str, str], port: int
) -> web.Application:
    app = web.Application()

    async def get_proresenter_xml(_: web.Request) -> web.Response:
        """Returns data in ProScoreboard/ProPresenter Datalink API format (XML)"""
        summary = await aggregator.get_rolling_summary()
        metrics = _get_formatted_metrics(summary)
        
        # Return ProScoreboard Datalink API format in XML
        xml_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<scoreboard>
    <sportMode>{metrics["sportMode"]}</sportMode>
    <ExitVelo>{metrics["ExitVelo"]}</ExitVelo>
    <LaunchAngle>{metrics["LaunchAngle"]}</LaunchAngle>
    <SpinRate>{metrics["SpinRate"]}</SpinRate>
    <PitchVelo>{metrics["PitchVelo"]}</PitchVelo>
    <HitDistance>{metrics["HitDistance"]}</HitDistance>
    <Hangtime>{metrics["Hangtime"]}</Hangtime>
</scoreboard>"""
        
        return web.Response(
            text=xml_content,
            content_type="application/xml"
        )
    
    async def get_livedata_xml(_: web.Request) -> web.Response:
        """Returns the livedata.xml file"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        livedata_path = os.path.join(script_dir, "livedata.xml")
        
        try:
            with open(livedata_path, 'r', encoding='utf-8') as f:
                xml_content = f.read()
            return web.Response(
                text=xml_content,
                content_type="application/xml"
            )
        except FileNotFoundError:
            return web.Response(
                text="livedata.xml not found",
                status=404
            )
    
    async def get_html_view(_: web.Request) -> web.Response:
        """Returns HTML view with black background and white monospace text"""
        summary = await aggregator.get_rolling_summary()
        metrics = _get_formatted_metrics(summary)
        
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="1">
    <title>Yakker Stream - Live Data</title>
    <style>
        body {{
            background-color: #000000;
            color: #ffffff;
            font-family: 'Courier New', Courier, monospace;
            padding: 40px;
            margin: 0;
        }}
        .container {{
            max-width: 800px;
            margin: 0 auto;
        }}
        h1 {{
            font-size: 36px;
            margin-bottom: 40px;
            text-align: center;
        }}
        .metric {{
            font-size: 28px;
            margin: 20px 0;
            padding: 15px;
            border: 2px solid #ffffff;
        }}
        .metric-label {{
            display: inline-block;
            width: 250px;
        }}
        .metric-value {{
            display: inline-block;
            font-weight: bold;
            font-size: 32px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>YAKKER STREAM - LIVE DATA</h1>
        <div class="metric">
            <span class="metric-label">Exit Velocity:</span>
            <span class="metric-value">{metrics["ExitVelo"]} mph</span>
        </div>
        <div class="metric">
            <span class="metric-label">Launch Angle:</span>
            <span class="metric-value">{metrics["LaunchAngle"]}°</span>
        </div>
        <div class="metric">
            <span class="metric-label">Spin Rate:</span>
            <span class="metric-value">{metrics["SpinRate"]} rpm</span>
        </div>
        <div class="metric">
            <span class="metric-label">Pitch Velocity:</span>
            <span class="metric-value">{metrics["PitchVelo"]} mph</span>
        </div>
        <div class="metric">
            <span class="metric-label">Hit Distance:</span>
            <span class="metric-value">{metrics["HitDistance"]} ft</span>
        </div>
        <div class="metric">
            <span class="metric-label">Hang Time:</span>
            <span class="metric-value">{metrics["Hangtime"]} sec</span>
        </div>
    </div>
</body>
</html>"""
        
        return web.Response(
            text=html_content,
            content_type="text/html"
        )

    app.add_routes([
        web.get("/", get_html_view),
        web.get("/data.xml", get_proresenter_xml),
        web.get("/livedata.xml", get_livedata_xml)
    ])
    return app


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Stream YakkerTech data to XML for ProScoreboard")
    parser.add_argument("--ws-url", default=DEFAULT_WS_URL, help="YakkerTech websocket URL")
    parser.add_argument(
        "--auth-header",
        default=DEFAULT_AUTH_RAW,
        help="Authorization header (e.g. 'Authorization: Basic ...')",
    )
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Local HTTP port")
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Use built-in demo data instead of connecting to YakkerTech",
    )
    parser.add_argument(
        "--no-console",
        action="store_true",
        help="Silence console metric updates",
    )
    return parser.parse_args()


async def _run_server(app: web.Application, port: int) -> web.AppRunner:
    runner = web.AppRunner(app, access_log=None)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", port)
    await site.start()
    print(f"✅ ProScoreboard XML API available at http://localhost:{port}", file=sys.stderr, flush=True)
    return runner


async def main() -> None:
    args = parse_args()
    # Set logging to WARNING level to suppress INFO messages
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )

    aggregator = MetricAggregator()
    status: Dict[str, str] = {"connection": "starting"}
    app = build_app(aggregator, status, args.port)
    runner = await _run_server(app, args.port)

    stop_event = asyncio.Event()

    def _handle_signal() -> None:
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            asyncio.get_event_loop().add_signal_handler(sig, _handle_signal)
        except NotImplementedError:
            # Windows compatibility; not expected on Mac.
            signal.signal(sig, lambda *_: stop_event.set())

    # Start periodic updater task
    updater_task = asyncio.create_task(periodic_updater(aggregator))
    
    # Start livedata.xml updater task
    xml_updater_task = asyncio.create_task(update_livedata_xml(aggregator))

    if args.demo:
        feed_task = asyncio.create_task(
            demo_feed(aggregator, status, echo_console=not args.no_console)
        )
    else:
        feed_task = asyncio.create_task(
            YakkerStreamer(
                ws_url=args.ws_url,
                auth_value=_extract_auth_value(args.auth_header),
                aggregator=aggregator,
                status=status,
                echo_console=not args.no_console,
            ).run()
        )

    await stop_event.wait()
    updater_task.cancel()
    xml_updater_task.cancel()
    feed_task.cancel()
    try:
        await updater_task
    except asyncio.CancelledError:
        pass
    try:
        await xml_updater_task
    except asyncio.CancelledError:
        pass
    try:
        await feed_task
    except asyncio.CancelledError:
        pass
    await runner.cleanup()
    print("✅ Yakker stream shut down.", file=sys.stderr, flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
