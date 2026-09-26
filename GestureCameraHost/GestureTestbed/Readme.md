
# Gesture Testbed — no developer account, no extension target

A single, ordinary macOS App target. Camera access only requires a
free Apple ID / personal team for local signing — no System Extension
entitlement is requested anywhere in this target.

## Setup

1. This can be added as a second target in the same Xcode project
   (recommended — see rationale below), independent of
   `GestureCameraHost` and the camera extension target.
2. File → New → Target → macOS → App. Name it, for example,
   `GestureTestbed`.
3. Add all files in this `Testbed/` folder to that target only.
4. The `Shared/`, `Extension/`, and original `HostApp/` files are not
   added to this target — this folder is self-contained (it has its
   own copies of `GestureClassifier` and `FrameCompositor` that do not
   depend on App Groups).
5. Target's Info tab (or Info.plist):
   - Key: `Privacy - Camera Usage Description` (`NSCameraUsageDescription`)
   - Value: a description such as "Used to test gesture detection
     locally."
6. Signing & Capabilities tab: a personal/free Apple ID team is
   sufficient. App Sandbox's Camera capability, if enabled by default,
   is a normal, unrestricted entitlement and works on a free account.
7. Running the target (⌘R) and granting the camera permission prompt
   produces a window with the raw feed on one side, composited feed on
   the other, and controls to load an overlay image, switch between
   sticker and full-frame mode, and adjust hold-frame count and
   cooldown live. The classifier state text shows `confirming` counts
   incrementing while the gesture is held.

## Why a separate target rather than reusing the host app target

- The host app target likely already declares an `@main` entry point;
  `GestureTestbedApp.swift` also declares one, and two in a single
  target will not compile.
- The Camera Extension template typically wires the extension into the
  host app target's build phases (an "Embed Foundation Extensions"
  step or similar), so building the host app scheme also attempts to
  build and sign the extension target — which fails without the
  System Extension entitlement. A separate target avoids this
  entirely, with no build-phase changes required and none to reverse
  later.
- Scheme switching (top-left scheme selector in Xcode) toggles between
  `GestureTestbed` and `GestureCameraHost` without either target
  affecting the other.

## What this validates

- Hand pose detection accuracy and confidence values under a given
  lighting/webcam setup.
- Whether the "extended middle finger, other fingers folded" heuristic
  in `HandPoseDetector.swift` needs tuning (false positives on a fist,
  false negatives at an angle, etc.) — visible directly in the
  confidence readout.
- Whether the hold-duration and cooldown defaults hold up in practice,
  adjustable live via the steppers rather than through a recompile.
- Overlay compositing correctness (positioning, scaling, sticker vs.
  full-frame) without any other app needing to pick up the feed.

## What this does not validate

- Whether the composited output reaches Zoom/Meet/FaceTime as a
  selectable camera — that is the system-extension layer, gated on
  Developer Program membership, and is untouched by this testbed.
- Extension lifecycle behavior (activation approval flow, the
  extension process being started/stopped by the OS, mach service
  communication) — none of that exists in this simplified target.

Once Developer Program access is available, the classifier/detector/
compositor logic validated here transfers directly: `LocalConfig` is
replaced by the App-Group-backed `SharedConfig`, and the same calls
are wired into `CameraExtensionStreamSource`'s capture callback.
