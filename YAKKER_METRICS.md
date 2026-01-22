# Yakker Data Metrics Reference

This document lists all the data points available from the YakkerTech API that could potentially be integrated into the ProScoreboard display.

## Currently Mapped Metrics

These metrics are currently being pulled from Yakker and sent to ProScoreboard:

| Yakker Metric | ProScoreboard XML Location | Description | Status |
|---------------|---------------------------|-------------|--------|
| Exit Velocity (`ExitSpeedMPH`) | `<hitting h="">` | Speed of the ball off the bat in MPH | **ACTIVE** |
| Launch Angle (`AngleDegrees`) | `<hitting rbi="">` | Angle of the ball off the bat in degrees | **ACTIVE** |
| Hit Distance (`DistanceFeet`) | `<hitting double="">` | Carry distance of the batted ball in feet | **ACTIVE** |
| Hang Time (`HangTimeSeconds`) | `<hitting triple="">` | Time the ball stays in the air | **ACTIVE** |
| Pitch Velocity (`ZoneSpeedMPH` or `RelSpeedMPH`) | `<pitching er="">` | Speed of the pitch in MPH | **ACTIVE** |
| Spin Rate (`SpinRateRPM`) | `<pitching pitches="">` | Spin rate of the pitch in RPM | **ACTIVE** |

> **Note:** Hit distance only registers when the payload reports at least 80 feet of carry so that catcher throwbacks do not overwrite live batted ball data. Hang time follows the same event validation path as exit velocity/launch angle.

## Available Pitch Data Metrics

All metrics from `pitch_data` in the Yakker API:

### Release Metrics
- `ReleaseAccuracy` - Quality indicator for release measurements (low/medium/high)
- `RelSpeedMPH` - Release speed in miles per hour
- `VertRelAngleDegrees` - Vertical release angle in degrees
- `HorzRelAngleDegrees` - Horizontal release angle in degrees
- `RelHeightFeet` - Release height in feet
- `RelSideFeet` - Release side position in feet
- `RubberFeet` - Distance from rubber in feet
- `ExtensionFeet` - Extension beyond rubber in feet
- `ExtensionAccurate` - Whether extension measurement is accurate (boolean)

### Plate Location Metrics
- `ZoneAccuracy` - Quality indicator for zone measurements (low/medium/high)
- `PlateLocHeightFeet` - Plate location height in feet
- `PlateLocSideFeet` - Plate location side position in feet
- `ZoneSpeedMPH` - Speed at the plate in miles per hour *(ACTIVE - currently mapped)*
- `ZoneTimeSeconds` - Time to reach the plate in seconds

### Approach Angle Metrics
- `VertApprAngleDegrees` - Vertical approach angle in degrees
- `HorzApprAngleDegrees` - Horizontal approach angle in degrees

### Spin Metrics
- `SpinRateRPM` - Spin rate in revolutions per minute *(ACTIVE - currently mapped)*
- `SpinAxisDegrees` - Spin axis orientation in degrees
- `Tilt` - Clock-face tilt representation (e.g., "1:15")
- `SpinEfficiencyPercent` - Spin efficiency percentage
- `EffectiveSpinRPM` - Effective spin rate in RPM
- `GyroSpinRPM` - Gyro spin component in RPM

### Break Metrics
- `VertBreakInches` - Vertical break in inches
- `InducedVertBreakInches` - Induced vertical break in inches
- `HorzBreakInches` - Horizontal break in inches

### Trajectory Physics
- `x0`, `y0`, `z0` - Initial position coordinates
- `vx0`, `vy0`, `vz0` - Initial velocity components
- `ax0`, `ay0`, `az0` - Acceleration components
- `pfxx`, `pfxz` - Pitch fx components

### Enhanced Yakker Metrics (prefixed with `yt_`)
- All of the above metrics have `yt_` versions with refined calculations
- Additional `yt_` specific metrics:
  - `yt_PitchSpinConfidence` - Confidence score for spin measurements
  - `yt_OutOfPlaneDegrees` - Out of plane angle
  - `yt_FSRIPercent` - Forward spin rate index percentage
  - `yt_SeamLatDegrees`, `yt_SeamLongDegrees` - Seam orientation
  - `yt_ReleaseDistanceFeet` - Release distance
  - `yt_SpinComponent[X/Y/Z]` - Spin vector components
  - `yt_R0` - Rotation matrix

## Available Hit Data Metrics

All metrics from `hit_data` in the Yakker API:

### Basic Hit Metrics
- `ExitAccuracy` - Quality indicator for exit measurements (low/medium/high)
- `ExitSpeedMPH` - Exit velocity off the bat in miles per hour *(ACTIVE - currently mapped)*
- `AngleDegrees` - Launch angle in degrees *(ACTIVE - currently mapped)*
- `DirectionDegrees` - Direction angle in degrees

### Distance & Trajectory
- `GroundAccuracy` - Quality indicator for ground measurements (low/medium/high)
- `DistanceFeet` - Total distance traveled in feet
- `BearingDegrees` - Bearing direction in degrees
- `HangTimeSeconds` - Time in the air in seconds

### Landing Location
- `PositionAt110XFeet`, `PositionAt110YFeet`, `PositionAt110ZFeet` - Position at 110 feet
- `yt_GroundLocationXFeet`, `yt_GroundLocationYFeet` - Ground landing coordinates
- `yt_HitLocationXFeet`, `yt_HitLocationYFeet`, `yt_HitLocationZFeet` - Hit location coordinates

### Velocity Components
- `yt_HitVelocityXMPH`, `yt_HitVelocityYMPH`, `yt_HitVelocityZMPH` - Velocity vector components
- `yt_EffectiveBattingSpeedMPH` - Effective bat speed

### Hit Spin Metrics
- `HitSpinRateRPM` - Spin rate of the batted ball in RPM
- `yt_HitSpinConfidence` - Confidence score for hit spin measurements
- `yt_HitBreakXFeet`, `yt_HitBreakYFeet` - Break distance components
- `yt_HitBreakTSeconds` - Time to max break
- `yt_HitSpinComponent[X/Y/Z]` - Hit spin vector components
- `yt_R0` - Rotation matrix for hit

## Additional Event Data

### Aero Data
- `external_conditions` - Contains:
  - `temp_f` - Temperature in Fahrenheit
  - `rel_humid` - Relative humidity percentage
  - `bar_pres_in` - Barometric pressure in inches
  - `elevation_ft` - Elevation in feet
  - `lat`, `lon` - Geographic coordinates
  - `epoch_time` - Unix timestamp
  - `source_description` - Data source description
- `model_name` - Aerodynamic model version

### Event Metadata
- `ball` - Type of baseball used (e.g., "major league baseball")
- `contributing_events` - Array of UUIDs of contributing observations
- `event_found` - Boolean indicating if event was found
- `server_time_now` - Server timestamp
- `event_uuid` - Unique identifier for the event

## Notes on Data Aggregation

The program currently implements smart data handling:
- **Duplicate Readings**: When multiple readings come in for the same event, they are averaged
- **Invalid Data**: N/A values and invalid readings are ignored in calculations
- **Rolling Average**: Uses a 1-second rolling buffer to smooth noisy readings
- **Stale Data**: Data older than 10 seconds is not displayed

## Future Expansion Ideas

Potential metrics to add to the ProScoreboard display:
1. Hit distance (`DistanceFeet`)
2. Hang time (`HangTimeSeconds`)
3. Spin efficiency (`SpinEfficiencyPercent`)
4. Vertical break (`InducedVertBreakInches`)
5. Horizontal break (`HorzBreakInches`)
6. Hit spin rate (`HitSpinRateRPM`)
7. Temperature and weather conditions
8. Bearing/direction of hit

## Reference

For complete API details and field definitions, refer to the YakkerTech API documentation.
