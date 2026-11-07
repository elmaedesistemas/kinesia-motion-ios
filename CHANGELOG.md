# Changelog

## 0.4.0 · 2026-11-06

3D measurement, opt-in.

- `Pose.world`: optional 3D positions (meters, y up) for the joints in `points`. `pose.imageOnly` drops them.
- `Measure.value(in:side:)` measures in 3D when every joint it needs has a world point, and on the
  image otherwise. `imageValue`, `worldValue` and `value(in:side:space:)` with `MeasureSpace` force one space.
- `VisionPoseProvider(world: true)` and `VideoPoseProvider(world: true)` also run Vision's 3D body pose
  (`VNDetectHumanBodyPose3DRequest`). Off by default, so nothing changes for existing apps.
- `kinesia-validate` measures every video in 2D and 3D and writes `resultados.csv` and `resultados-3d.csv`.

## 0.3.0 · 2026-10-25

- `kinesia-validate` (development tool): `swift run kinesia-validate mediciones.csv` reads each trial's
  video with `VideoPoseProvider`, takes the angle at the end of the range and compares it with the
  goniometer reading. Per exercise and side it reports mean absolute error, bias, worst error, share
  within ±5° and pass/fail, and writes `resultados.csv`.
- `Validation/` has the CSV template and the recording instructions for the pilot.
- No changes to the `KinesiaMotion` or `KinesiaMotionVision` APIs.

## 0.2.0 · 2026-10-24

- `VideoPoseProvider` (KinesiaMotionVision): poses from a video file with the same Vision body pose
  as the live camera, on iOS and macOS. `readAll()` returns every pose at once.
- `VisionPoseProvider` and `VideoPoseProvider` share the Vision → `Pose` conversion.

## 0.1.0 · 2026-10-24

First stable release, used by the Kinesia patient app.

### Measurement
- `Pose`, `Joint` and `BodySide`, with per-joint confidence and the camera image size.
- `Measure` and `Geometry`: joint angles from three landmarks, and segment angles against the vertical.
- `LandmarkRef` with JSON support, so exercises can be described as data.

### Exercises
- `ExerciseDefinition` and `FormRule`: a rep with a compensation doesn't count.
- `RepEngine` with hysteresis, the peak of each rep and form checking.
- Hold exercises: a rep counts once the position is held and steady.
- `ExerciseLibrary`: elbow flexion, knee flexion (standing and seated), shoulder flexion and abduction,
  hip flexion and abduction, ankle dorsiflexion (lunge) and neck side bend.

### Sessions
- `MotionSession` with snapshots, events, visibility and the first measurement (baseline).
- Measurement quality: setup check before starting, per-rep metrics and confidence.

### Input
- `PoseProvider` and `RecordedPoseProvider` for tests and replays.
- `KinesiaMotionVision`: `VisionPoseProvider` on Apple Vision, mirroring the selfie camera.

### Notes
- Renamed from KinetiaMotion to KinesiaMotion in 0.1.0-alpha.6.
- Angle accuracy against a goniometer (target ±5°) has not been validated yet; that happens in the pilot.
