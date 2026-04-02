# Live Streaming Codec Plan

This document maps the current `LiveFileWriter` / `LiveFileWritingDecoder` behavior to Apple guidance and turns that into an implementation plan.

## Scope

Files in scope:

- `Sources/SnapCoreEngine/Recording/FileWriting/LiveFileWriter.swift`
- `Sources/SnapCoreEngine/Recording/FileWriting/LiveFileWritingDecoder.swift`

Primary symptom:

- Noticeable live-stream delay that grows large enough to be obvious to the user.

## Apple Documentation

Core VideoToolbox encoder / decoder references:

- `VTCompressionSession` API collection:
  https://developer.apple.com/documentation/videotoolbox/vtcompressionsession-api-collection
- `kVTCompressionPropertyKey_RealTime`:
  https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_realtime
- `kVTCompressionPropertyKey_AllowFrameReordering`:
  https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_allowframereordering
- `kVTCompressionPropertyKey_SupportedPresetDictionaries`:
  https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_supportedpresetdictionaries
- `kVTVideoEncoderSpecification_EnableLowLatencyRateControl`:
  https://developer.apple.com/documentation/videotoolbox/kvtvideoencoderspecification_enablelowlatencyratecontrol

Core Media format-description references:

- `CMFormatDescription` API collection:
  https://developer.apple.com/documentation/coremedia/cmformatdescription-api
- `CMVideoFormatDescriptionCreateFromH264ParameterSets(...)`:
  https://developer.apple.com/documentation/coremedia/cmvideoformatdescriptioncreatefromh264parametersets%28allocator%3Aparametersetcount%3Aparametersetpointers%3Aparametersetsizes%3Analunitheaderlength%3Aformatdescriptionout%3A%29

Apple notes on real-time pipelines and buffering:

- Technical Note TN2445, `Handling Frame Drops with AVCaptureVideoDataOutput`:
  https://developer.apple.com/library/archive/technotes/tn2445/_index.html
- `Polling Versus Run-Loop Scheduling`:
  https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Streams/Articles/PollingVersusRunloop.html
- `Working with Streams`:
  https://developer.apple.com/library/archive/documentation/Networking/Conceptual/CFNetwork/CFStreamTasks/CFStreamTasks.html

## What Apple Docs Imply For This Pipeline

Some of the fixes below are direct from Apple docs; some are engineering inferences from those docs applied to this codebase.

Direct Apple guidance:

- A `VTCompressionSession` should be configured before encode begins, and `VTCompressionSessionPrepareToEncodeFrames` exists specifically to let the encoder allocate resources up front.
- `kVTCompressionPropertyKey_RealTime` should be enabled for real-time encoding.
- `kVTCompressionPropertyKey_AllowFrameReordering = false` avoids B-frame reordering, which reduces display-vs-decode ordering latency.
- Apple exposes `kVTCompressionPreset_VideoConferencing` via supported preset dictionaries as a baseline for low-latency interactive video.
- H.264 decoders can be initialized from SPS/PPS using `CMVideoFormatDescriptionCreateFromH264ParameterSets(...)`.
- Apple’s TN2445 is explicit that real-time video callbacks must stay efficient, and that allowing work to queue behind real-time input creates visible lag.
- Apple’s stream docs recommend run-loop scheduling / readiness-driven stream IO instead of blocking loops.

Reasoned inferences for this code:

- Calling `onFrameWritten` before the encoder callback runs is semantically wrong for a live stream because the frame has only been submitted, not encoded or flushed.
- Blocking `OutputStream.write` from the encode callback path can create backpressure that turns into growing end-to-end delay.
- Waiting for SPS/PPS to arrive opportunistically inside the payload can create startup delay and recovery delay after reconnect or packet loss.
- Converting every decoded frame from `CVImageBuffer` to `CGImage` on the hot path is expensive and should be treated as optional display work, not required transport work.

## Current Problems

### 1. The writer reports completion too early

`LiveFileWriter.write(...)` calls `onFrameWritten()` immediately after `VTCompressionSessionEncodeFrame(...)` returns success.

Why this is a problem:

- Per Apple’s `VTCompressionSession` model, encode submission and compressed output delivery are separate steps.
- A successful `VTCompressionSessionEncodeFrame(...)` call means the frame was accepted by the encoder, not that bytes were emitted to the stream.
- This makes upstream code think the frame is done before the stream actually receives it.

Required change:

- Move frame-complete signaling so it happens only after the compressed packet is successfully written to the output stream.

### 2. The encoder is not fully configured for low latency

Current code only sets:

- `kVTCompressionPropertyKey_RealTime`
- `kVTCompressionPropertyKey_AllowFrameReordering = false`

Why this is incomplete:

- The Apple API collection shows encoder configuration should happen before encode starts.
- The current setup does not call `VTCompressionSessionPrepareToEncodeFrames`.
- The current setup does not set an expected frame rate, a keyframe cadence, or a low-latency preset / rate-control hint.

Required change:

- Configure the session up front with low-latency properties and prepare it before the first frame.

### 3. SPS/PPS handling is incomplete

`sendFormatDescriptionIfNeeded(...)` is effectively empty.

Why this is a problem:

- The decoder reconstructs format state from SPS/PPS found inside payload NAL units.
- Apple provides `CMVideoFormatDescriptionCreateFromH264ParameterSets(...)` specifically for creating decoder format descriptions from H.264 parameter sets.
- If SPS/PPS do not appear immediately, the decoder cannot initialize promptly.
- Startup delay then depends on when an IDR plus parameter sets happens to arrive.

Required change:

- Extract SPS/PPS from the writer-side format description and transmit them deterministically.
- Rebuild the decoder format description from that transmitted metadata instead of waiting for a lucky frame.

### 4. Stream writing is blocking

`writeAll(...)` spins until every byte is written.

Why this is a problem:

- Apple’s stream docs say blocking is a core problem in stream processing.
- A live pipeline should write when the stream can accept bytes, not spin on the encode path.
- If the network or peer slows down, latency grows because the writer keeps old frames instead of favoring freshness.

Required change:

- Schedule the `OutputStream` on a run loop or otherwise respect `hasSpaceAvailable`.
- Queue pending encoded packets and drain them only when the stream is writable.
- Cap the queue size and drop stale frames if the app cannot keep up in real time.

### 5. Decoder hot path does too much work

The decoder currently:

- Copies packet payload into `Data`
- Copies again into `CMBlockBuffer`
- Decodes
- Converts `CVImageBuffer` to `CIImage`
- Converts `CIImage` to `CGImage`
- Dispatches to the main queue for delivery

Why this matters:

- TN2445 says real-time frame processing must stay within the frame budget.
- If display conversion is slower than decode or input, a queue forms and the user sees lag.

Required change:

- Keep decode and transport separate from UI conversion.
- Deliver `CVPixelBuffer` or `CVImageBuffer` when possible.
- If `CGImage` remains necessary for UI, make it an opt-in presentation step after the latest frame is selected.

## Fix Plan

## Phase 1: Correct pipeline semantics

1. Change `LiveFileWriter` so submission success is not treated as write completion.
2. Attach a frame token or timestamp to the encoder callback path.
3. Invoke `onFrameWritten` only after `processCompressedFrame(...)` successfully writes the packet.
4. If the stream write fails, surface that as a transport failure instead of silently swallowing it with `try?`.

Expected outcome:

- Recorded frame metadata and perceived stream progress match what actually reached the socket.

## Phase 2: Configure the encoder for interactive latency

Apply Apple-recommended low-latency encoder configuration before the first frame:

1. Keep `kVTCompressionPropertyKey_RealTime = true`.
2. Keep `kVTCompressionPropertyKey_AllowFrameReordering = false`.
3. Add `kVTCompressionPropertyKey_ExpectedFrameRate`.
4. Add `kVTCompressionPropertyKey_MaxKeyFrameInterval` and/or `kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration`.
5. Prefer the `kVTCompressionPreset_VideoConferencing` preset dictionary when supported, then override project-specific values.
6. Try `kVTVideoEncoderSpecification_EnableLowLatencyRateControl` in the encoder specification dictionary when available.
7. Call `VTCompressionSessionPrepareToEncodeFrames(...)` after configuration and before encode starts.

Recommended starting values:

- Expected frame rate: use the configured capture FPS.
- Keyframe interval duration: 1 second.
- Keyframe interval count: equal to FPS.

Why these values:

- Short keyframe cadence reduces startup and recovery latency.
- Interactive video generally benefits more from freshness than from long-GOP compression efficiency.

## Phase 3: Make SPS/PPS explicit

1. On the writer, extract SPS/PPS from `CMSampleBufferGetFormatDescription(...)` using `CMVideoFormatDescriptionGetH264ParameterSetAtIndex(...)`.
2. Send a small control packet for format metadata before the first keyframe and whenever the format changes.
3. On the decoder, parse that control packet and build `CMVideoFormatDescription` immediately with `CMVideoFormatDescriptionCreateFromH264ParameterSets(...)`.
4. Continue to accept inline SPS/PPS from payloads as a fallback, but do not rely on them for startup.

Expected outcome:

- Decoder initialization becomes deterministic.
- Reconnect and format-change recovery become much faster.

## Phase 4: Remove blocking stream writes

1. Stop writing encoded packets directly in the encoder callback path.
2. Add a bounded packet queue owned by the writer.
3. Schedule the `OutputStream` on a run loop and drain only on `hasSpaceAvailable`.
4. If queue depth exceeds a small threshold, drop older non-key frames first.
5. Keep the newest keyframe and the newest recent frames rather than preserving every frame.

This step is an inference from Apple’s stream docs plus TN2445’s real-time guidance:

- In a live stream, bounded latency is usually more important than perfect frame retention.

Recommended queue policy:

- Byte cap and packet count cap.
- Prefer dropping stale delta frames over letting latency grow without bound.

## Phase 5: Reduce decoder work on the critical path

1. Add a lower-level callback such as `onFrameBuffer: (CVImageBuffer, CMTime) -> Void`.
2. Keep `onFrameImage` only as a convenience layer for UI consumers that truly need `CGImage`.
3. If UI wants a preview, coalesce updates so only the most recent decoded frame is converted.
4. Avoid decoding work on the main thread; only final UI publication should touch the main actor.

Expected outcome:

- Lower decode-side CPU/GPU cost.
- Less risk that display conversion becomes the latency bottleneck.

## Phase 6: Add backpressure metrics and logging

Add instrumentation before and after the above changes:

1. Capture timestamp
2. Encoder submit timestamp
3. Encoder callback timestamp
4. Packet-enqueued timestamp
5. Packet-written timestamp
6. Packet-read timestamp
7. Decoder-output timestamp
8. UI-presented timestamp

Track:

- End-to-end latency
- Encoder queue latency
- Socket write backlog
- Decoder throughput
- Dropped-frame counts
- Keyframe interval actually observed

This will let you tell whether latency is caused by:

- capture backlog
- encoder buffering
- socket backpressure
- decoder backlog
- UI conversion backlog

## Phase 7: Update stop / teardown behavior

1. On stop, call `VTCompressionSessionCompleteFrames(..., untilPresentationTimeStamp: .invalid)` before invalidation so pending frames are flushed intentionally.
2. Invalidate and release compression / decompression sessions cleanly.
3. Reset cached SPS/PPS and queue state on restart.

## Test Plan

Unit tests:

1. Writer does not report frame completion before encoded packet write completes.
2. Decoder can initialize from an explicit SPS/PPS control packet before frame payload arrives.
3. Writer queue drops stale delta frames when the output stream stalls.
4. Restart clears old format state and does not reuse stale SPS/PPS.

Integration tests:

1. Measure glass-to-glass latency on a local loopback stream.
2. Simulate slow stream writes and verify latency remains bounded.
3. Simulate reconnect and verify first-frame recovery occurs on the next keyframe window.
4. Validate that no unbounded memory growth occurs during prolonged backpressure.

## Suggested Implementation Order

1. Fix `onFrameWritten` semantics.
2. Add encoder configuration and `PrepareToEncodeFrames`.
3. Implement explicit SPS/PPS transport.
4. Replace blocking writes with a bounded async packet queue.
5. Reduce decoder/UI hot-path work.
6. Add latency instrumentation and regression tests.

## Bottom Line

The delay is not one single bug. It is the combination of:

- premature "frame written" signaling
- incomplete low-latency encoder configuration
- missing explicit SPS/PPS transport
- blocking output-stream writes
- expensive decode-to-display conversion on the hot path

Apple’s docs point toward the same overall strategy:

- configure the encoder explicitly for real-time interactive use
- keep callbacks efficient
- avoid unbounded buffering
- initialize the decoder deterministically from H.264 parameter sets
- use nonblocking stream IO
