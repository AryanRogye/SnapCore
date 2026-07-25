# Adding a New Recognition Handler to SnapCore

This doc describes the pattern used to add a new Vision-based recognition
feature (body pose, face tracking, etc.) to `SnapCore`. Follow these steps in
order and use the referenced implementations as working examples.

Start with a thin, compiling handler and use Vision's typed request and
observation APIs to determine its result type. Runtime inspection can help
validate behavior, but it is not required to discover the shape of a Vision
observation.

`X`/`x` below stand in for your new feature's name (e.g. `Hand`/`hand`),
following the same convention as the existing `Body`/`body` and `Face`/`face`
features.

---

## 1. Choose the Vision request and result type

Identify the Vision request and its typed observation before defining the
public callback. Prefer a framework type such as `[CGRect]` when it expresses
the result cleanly.

Create a custom model only when Vision's raw result is awkward for clients.
Place custom models under
[`Recognition/Models/`](./Services/Recognition/Models/) and make public model
APIs `public`, `Sendable` where appropriate, and succinctly documented.

For example,
[`MultiFaceRecognitionHandler`](./Services/Recognition/MultiFaceRecognitionHandler.swift)
uses `[CGRect]` because that is already what
`VNFaceObservation.boundingBox` provides. Body recognition uses `BodyPose`
because the source data is keyed by Vision joint names and split across
multiple joint groups.

---

## 2. Create the recognition handler

**Location:** [`Recognition/`](./Services/Recognition/)

Create `XRecognitionHandler.swift`, mirroring
`BodyRecognitionHandler` or `MultiFaceRecognitionHandler`. The handler should:

- inherit from `NSObject`;
- conform to `AVCaptureVideoDataOutputSampleBufferDelegate` and
  `RecognitionHandler`;
- own a `VNSequenceRequestHandler`;
- retain its callback, orientation, processing queue, and optional
  `AdaptiveThrottle`;
- extract a `CVPixelBuffer` from each sample buffer;
- perform the typed Vision request with the configured orientation; and
- return the recognition result, pixel buffer, and processing interval through
  its callback.

If adaptive throttling compares old and new results, implement comparison logic
for the new result type. The shared `RecognitionHandler.isCloseBy` overloads
currently support only `[CGRect]` and `[BodyPose]`.

---

## 3. Add the public methods to the protocol

**File:** [`CameraCaptureProviding`](./Protocols/CameraCaptureProviding.swift)

Add and succinctly document `setOnXResult(_:)` with the chosen result type.
Then add `startCameraWithXTracking`, mirroring the existing tracking start
functions:

```swift
func startCameraWithFaceTracking(
    with device: AVCaptureDevice,
    fps: CameraFPS,
    cameraPosition: CameraPosition,
    colorSpace: CameraColorSpace,
    optimize: Bool
) async throws
```

```swift
func startCameraWithBodyTracking(
    with device: AVCaptureDevice,
    fps: CameraFPS,
    cameraPosition: CameraPosition,
    colorSpace: CameraColorSpace,
    optimize: Bool
) async throws
```

Add `startCameraWithXTracking` with the same signature.

---

## 4. Add callback storage and retain the handler

**File:** [`CameraCaptureService`](./Services/CameraCaptureService.swift)

Add both properties:

```swift
internal var onXResult: (([XResult], CVPixelBuffer, CFAbsoluteTime) -> Void)?
internal var xRecognitionHandler: XRecognitionHandler?
```

Adapt `[XResult]` to the actual result type. The service-level callback storage
allows clients to register their callback before a handler exists. The handler
property is also required to retain the video output delegate.

---

## 5. Implement the service callback setter

Create `CameraCaptureService+setOnXResult.swift`, mirroring
[`CameraCaptureService+setOnBodyResult`](./Services/CameraCaptureService+setOnBodyResult.swift)
or
[`CameraCaptureService+setOnFaceBoxes`](./Services/CameraCaptureService+setOnFaceBoxes.swift).

The current service pattern stores the callback:

```swift
public func setOnXResult(
    _ handler: @escaping ([XResult], CVPixelBuffer, CFAbsoluteTime) -> Void
) {
    self.onXResult = handler
}
```

Register callbacks before calling `startCameraWithXTracking`. The existing
setters do not replace the callback on a handler that is already running. If
runtime callback replacement is required, update both the stored callback and
the active handler deliberately.

---

## 6. Attach the handler to the video output

**File:** [`CameraCaptureService+startCamera`](./Services/CameraCaptureService+startCamera.swift)

Add an `attachXTrackingOutput` helper. It must:

1. Instantiate `XRecognitionHandler` with `optimize` and the correct image
   orientation.
2. Copy the service's stored `onXResult` callback into the new handler.
3. Store the handler in `xRecognitionHandler` so the delegate remains alive.
4. Pass the handler to `addVideoOutput(in:handler:)`.

The existing orientation mapping is `.upMirrored` for the front camera and
`.right` for the back camera. Follow the existing handlers unless the selected
Vision request requires different orientation handling.

Recognition handlers receive the one `AVCaptureVideoDataOutput` stream. A
pixel-buffer-driven preview should use the `CVPixelBuffer` delivered with the
recognition callback. An `AVCaptureVideoPreviewLayer` attached directly to the
session does not depend on that callback.

---

## 7. Add the tracking start method

In `CameraCaptureService+startCamera.swift`, implement
`startCameraWithXTracking` using the same lifecycle as body and face tracking:

1. Stop the existing camera.
2. Create an `AVCaptureSession` and begin configuration.
3. Configure the selected input, FPS, position, and color space.
4. Attach the new recognition output.
5. Configure the video connection.
6. Commit configuration and start the session.
7. Store the session and update `cameraState`.

---

## 8. Verify the implementation

- Add deterministic tests for custom model conversion and stability-comparison
  logic. Do not use a live camera in unit tests.
- Run `swift build`.
- Run `swift test`.
- Test live capture separately with camera permission on macOS or iOS as
  applicable.
- Confirm a callback registered before startup receives the expected result,
  `CVPixelBuffer`, and processing interval.
