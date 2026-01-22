#!/usr/bin/env python3
"""Terminal dashboard for live Yakker metrics."""

import argparse
import asyncio
import logging
import os
import signal
import sys
import time
from typing import Any, Dict, List, Optional, Tuple

from yakker_stream import (
    DEFAULT_AUTH_RAW,
    DEFAULT_WS_URL,
    MetricAggregator,
    YakkerStreamer,
    _extract_auth_value,
    demo_feed,
)

DEFAULT_REFRESH_SECONDS = float(os.getenv("YAKKER_CLI_REFRESH", "0.25"))

METRIC_DEFINITIONS = (
    ("Pitch Velocity", "pitch_velocity_mph", "mph", 1),
    ("Spin Rate", "spin_rate_rpm", "rpm", 1),
    ("Exit Velocity", "exit_velocity_mph", "mph", 1),
    ("Launch Angle", "launch_angle_deg", "deg", 1),
)

RAW_METRIC_DEFINITIONS = (
    ("Hang Time", ("hit_data", "HangTimeSeconds"), "s", 1),
    ("Hit Distance", ("hit_data", "DistanceFeet"), "ft", 1),
    ("Hit Spin Rate", ("hit_data", "HitSpinRateRPM"), "rpm", 1),
)

MIN_LABEL_WIDTH = 16
MAX_LABEL_WIDTH = 32
MIN_VALUE_WIDTH = 12
MAX_VALUE_WIDTH = 48


def _truncate(text: str, width: int) -> str:
    if len(text) <= width:
        return text
    if width <= 3:
        return text[:width]
    return text[: width - 3] + "..."


def _pad(text: str, width: int) -> str:
    truncated = _truncate(text, width)
    padding = " " * max(0, width - len(truncated))
    return truncated + padding


def _render_table(
    rows: List[Tuple[str, str]],
    *,
    title: Optional[str] = None,
    min_label: int = MIN_LABEL_WIDTH,
    max_label: int = MAX_LABEL_WIDTH,
    min_value: int = MIN_VALUE_WIDTH,
    max_value: int = MAX_VALUE_WIDTH,
) -> List[str]:
    if not rows:
        return []
    label_width = max(min_label, min(max(len(label) for label, _ in rows), max_label))
    value_width = max(min_value, min(max(len(value) for _, value in rows), max_value))
    border = f"+{'-' * (label_width + 2)}+{'-' * (value_width + 2)}+"
    header = f"| {'Metric':<{label_width}} | {'Value':<{value_width}} |"
    lines: List[str] = []
    if title:
        lines.append(title)
    lines.append(border)
    lines.append(header)
    lines.append(border)
    for label, value in rows:
        label_cell = _pad(label, label_width)
        value_cell = _pad(value, value_width)
        lines.append(f"| {label_cell} | {value_cell} |")
    lines.append(border)
    lines.append("")
    return lines


def _extract_raw_metric(
    payload: Optional[Dict[str, Any]], path: Tuple[str, ...]
) -> Optional[float]:
    if not payload:
        return None
    data: Any = payload
    for key in path:
        if not isinstance(data, dict) or key not in data:
            return None
        data = data[key]
    if data is None:
        return None
    try:
        return float(data)
    except (TypeError, ValueError):
        return None


def _format_payload_value(value: Any) -> str:
    if value is None:
        return "--"
    if isinstance(value, float):
        formatted = f"{value:.3f}".rstrip("0").rstrip(".")
        return formatted or "0"
    return str(value)


def _dict_rows(data: Dict[str, Any]) -> List[Tuple[str, str]]:
    return [(key, _format_payload_value(data[key])) for key in sorted(data.keys())]


def _build_raw_sections(payload: Dict[str, Any]) -> List[Tuple[str, List[Tuple[str, str]]]]:
    sections: List[Tuple[str, List[Tuple[str, str]]]] = []
    if not payload:
        return sections

    extra_rows: List[Tuple[str, str]] = []
    for label, path, unit, decimals in RAW_METRIC_DEFINITIONS:
        value = _extract_raw_metric(payload, path)
        formatted = _format_value(value, decimals)
        cell = f"{formatted} {unit}" if formatted != "--" else "--"
        extra_rows.append((label, cell))
    if extra_rows:
        sections.append(("live metrics", extra_rows))

    structured_keys = ("pitch_data", "hit_data")
    for key in structured_keys:
        data = payload.get(key)
        if isinstance(data, dict) and data:
            sections.append((key.replace("_", " "), _dict_rows(data)))

    remaining = {
        key: value
        for key, value in payload.items()
        if key not in structured_keys
    }
    if remaining:
        sections.append(("payload", _dict_rows(remaining)))

    return sections


class RawPayloadStore:
    """Keeps a copy of the most recent Yakker payload for terminal display."""

    def __init__(self) -> None:
        self._payload: Optional[Dict[str, Any]] = None
        self._updated_at: Optional[float] = None
        self._lock = asyncio.Lock()
        self._sections: List[Tuple[str, List[Tuple[str, str]]]] = []

    async def update(self, payload: Dict[str, Any]) -> None:
        async with self._lock:
            self._payload = payload
            self._updated_at = time.time()
            self._sections = _build_raw_sections(payload)

    async def snapshot(self) -> Optional[Dict[str, Any]]:
        async with self._lock:
            if self._payload is None:
                return None
            return {
                "updated_at": self._updated_at,
                "payload": self._payload,
                "sections": list(self._sections),
            }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Stream Yakker metrics directly to an ASCII terminal dashboard"
    )
    parser.add_argument(
        "--ws-url",
        default=DEFAULT_WS_URL,
        help="YakkerTech websocket URL",
    )
    parser.add_argument(
        "--auth-header",
        default=DEFAULT_AUTH_RAW,
        help="Authorization header (e.g. 'Authorization: Basic ...')",
    )
    parser.add_argument(
        "--refresh",
        type=float,
        default=DEFAULT_REFRESH_SECONDS,
        help="Seconds between terminal refreshes (default: %(default)s)",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Use built-in demo data instead of connecting to YakkerTech",
    )
    return parser.parse_args()


def _clear_screen() -> None:
    sys.stdout.write("\x1b[2J\x1b[H")
    sys.stdout.flush()


def _format_value(value: Optional[float], decimals: int) -> str:
    if value is None:
        return "--"
    return f"{value:.{decimals}f}"


def _metric_value(
    primary: Optional[Dict[str, Optional[float]]],
    fallback: Optional[Dict[str, Optional[float]]],
    key: str,
) -> Optional[float]:
    if primary and primary.get(key) is not None:
        return primary.get(key)
    if fallback and fallback.get(key) is not None:
        return fallback.get(key)
    return None


def _render_dashboard(
    rolling_summary: Optional[Dict[str, Optional[float]]],
    latest_summary: Optional[Dict[str, Optional[float]]],
    status: Dict[str, str],
    raw_snapshot: Optional[Dict[str, Any]],
) -> None:
    _clear_screen()
    lines: List[str] = []
    connection_state = status.get("connection", "starting").upper()
    active_summary = latest_summary or rolling_summary or {}
    event_id = active_summary.get("event_id") or "--"
    updated_at = active_summary.get("updated_at")
    if isinstance(updated_at, (int, float)):
        updated_str = time.strftime("%H:%M:%S", time.localtime(updated_at))
        age = time.time() - updated_at
        updated_line = f"{updated_str} ({age:.1f}s ago)"
    else:
        updated_line = "waiting for data"

    raw_updated = raw_snapshot.get("updated_at") if raw_snapshot else None
    if isinstance(raw_updated, (int, float)):
        raw_updated_str = time.strftime("%H:%M:%S", time.localtime(raw_updated))
        raw_age = time.time() - raw_updated
        raw_line = f"{raw_updated_str} ({raw_age:.1f}s ago)"
    else:
        raw_line = "waiting for payload"

    lines.append("YAKKER METRICS")
    lines.append("==============")
    lines.append("")
    lines.append(f"Connection : {connection_state}")
    lines.append(f"Last Event : {event_id}")
    lines.append(f"Last Update: {updated_line}")
    lines.append("")

    core_rows: List[Tuple[str, str]] = []
    for label, key, unit, decimals in METRIC_DEFINITIONS:
        value = _metric_value(rolling_summary, latest_summary, key)
        formatted = _format_value(value, decimals)
        cell = f"{formatted} {unit}" if formatted != "--" else "--"
        core_rows.append((label, cell))
    lines.extend(_render_table(core_rows, title="CORE METRICS"))

    lines.append("RAW METRICS")
    lines.append("-----------")
    lines.append(f"Payload Update: {raw_line}")
    lines.append("")
    if not raw_snapshot:
        lines.append("Waiting for Yakker payload...")
        lines.append("")
    else:
        sections: List[Tuple[str, List[Tuple[str, str]]]] = raw_snapshot.get("sections", [])
        for section, entries in sections:
            section_title = f"[{section.upper()}]"
            lines.extend(
                _render_table(
                    entries,
                    title=section_title,
                    min_label=20,
                    max_label=40,
                    min_value=16,
                    max_value=60,
                )
            )
    lines.append("Press Ctrl+C to exit.")
    lines.append("")
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.flush()


async def _display_loop(
    aggregator: MetricAggregator,
    status: Dict[str, str],
    raw_store: RawPayloadStore,
    refresh_seconds: float,
) -> None:
    refresh = max(0.1, refresh_seconds)
    try:
        while True:
            rolling_summary = await aggregator.get_rolling_summary()
            latest_summary = await aggregator.latest_summary()
            raw_snapshot = await raw_store.snapshot()
            _render_dashboard(rolling_summary, latest_summary, status, raw_snapshot)
            await asyncio.sleep(refresh)
    except asyncio.CancelledError:
        return


async def run_cli() -> None:
    args = parse_args()
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%H:%M:%S",
    )

    aggregator = MetricAggregator()
    raw_store = RawPayloadStore()
    status: Dict[str, str] = {"connection": "starting"}
    stop_event = asyncio.Event()

    loop = asyncio.get_running_loop()
    def _request_shutdown() -> None:
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _request_shutdown)
        except NotImplementedError:
            signal.signal(sig, lambda *_: stop_event.set())

    payload_hooks = [raw_store.update]

    if args.demo:
        feed_task = asyncio.create_task(
            demo_feed(
                aggregator,
                status,
                payload_hooks=payload_hooks,
            )
        )
    else:
        feed_task = asyncio.create_task(
            YakkerStreamer(
                ws_url=args.ws_url,
                auth_value=_extract_auth_value(args.auth_header),
                aggregator=aggregator,
                status=status,
                payload_hooks=payload_hooks,
            ).run()
        )

    def _stop_on_task_done(task: asyncio.Task[Any]) -> None:
        if task.cancelled():
            return
        exc = task.exception()
        if exc:
            logging.error("Task stopped with error: %s", exc)
        if not stop_event.is_set():
            stop_event.set()

    feed_task.add_done_callback(_stop_on_task_done)

    display_task = asyncio.create_task(
        _display_loop(aggregator, status, raw_store, args.refresh)
    )
    display_task.add_done_callback(_stop_on_task_done)

    try:
        await stop_event.wait()
    finally:
        for task in (feed_task, display_task):
            task.cancel()
        for task in (feed_task, display_task):
            try:
                await task
            except asyncio.CancelledError:
                pass


if __name__ == "__main__":
    try:
        asyncio.run(run_cli())
    except KeyboardInterrupt:
        pass
