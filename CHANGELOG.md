# Changelog

## 0.6.0 · 2026-11-12

Four new exercises, twelve in all. Same ids and thresholds as KinesiaMotion for Android 0.4.0.

- `shoulderExtension` (`shoulder.extension`): straight arm back, side view. Target 50°.
- `hipExtensionStanding` (`hip.extension.standing`): straight leg back, side view. Target 20°.
- `trunkFlexion` (`trunk.flexion`): forward bend, side view, region `back`. Reads the trunk's lean
  from vertical (shoulder over hip), which adds lumbar and hip flexion. Target 70°.
- `trunkLateralFlexion` (`trunk.lateralFlexion`): side bend, front view, region `back`. Reads the
  midline (neck to root) against vertical; run once per side. Target 30°.
- Extensions read the same angle as the matching flexion, which has no direction: the app tells the
  patient which way to move.
- `KinesiaValidate` accepts `hombro-extension`, `cadera-extension`, `tronco-flexion` and `tronco-lateral`.

## 0.5.4 · 2026-11-07

Fix: 3D points with the front camera now cover the whole arm.

- The 3D joints take their side from Vision's names. With 3D running on the un-mirrored image they
  are already the patient's; matching by position in the image found only a few joints on device.
- With `world: true`, `VisionPoseProvider` captures at 720p: at VGA, Vision's 3D model kept losing
  the person ("2D Pose estimation failed").

## 0.5.3 · 2026-11-06

Fix: 3D points with the front camera, for real this time.

- Vision's 3D body pose fails on mirrored orientations ("Unable to run HumanBodyPose3D pipeline",
  a NaN crop and a 0 × 0 buffer inside Vision). `VisionPoseProvider` now runs it on the un-mirrored
  image and matches each 3D joint back to the mirrored 2D image.
- If 3D still fails 60 frames in a row, `VisionPoseProvider` stops asking for it and poses stay 2D,
  so a device or camera that can't run it doesn't pay for it on every frame.

## 0.5.2 · 2026-11-06

Fix: Vision's 3D body pose failed on every live camera frame ("Unable to run HumanBodyPose3D pipeline").

- With `world: true`, `VisionPoseProvider` asks the camera for BGRA frames, and `VideoPoseProvider`
  reads videos as BGRA. The 3D pipeline couldn't convert the default YUV frames.
- Vision reads each live frame from its pixel buffer instead of the sample buffer.

## 0.5.1 · 2026-11-06

Fix: 3D points with the front camera.

- Each Vision 3D joint now goes to the 2D joint it lands on in the image, instead of trusting its
  left/right name. With the mirrored front camera and only one arm in view, the active arm's 3D points
  could be dropped, so measures stayed in 2D.
- When Vision can't place the camera, positions fall back to the body's own space (same angles).
- The 3D request runs apart from the 2D one, and the Xcode console says why 3D points are or aren't
  arriving (subsystem `one.kinesia.motion`, category `vision3d`), once per change.

## 0.5.0 · 2026-11-06

Choose 2D or 3D.

- `MotionSession(space:)` and `MotionSession.space`: `.image` always measures in 2D, `.world` always in 3D
  (needs a provider with `world: true`), nil (default) uses 3D whenever the pose has it. It can change live.
- `RepEngine.space` does the same without a session; form rules follow it too.

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
