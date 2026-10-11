# FacePing iOS starter

**FaceCheck**: a small SwiftUI app that enrols your face and verifies it live, on the iPhone, with a head-turn liveness check. Switch on airplane mode and it still matches.

It's built on [FacePing for iOS](https://github.com/faceping/faceping-ios), the FacePing Swift package. See the [iOS guide](https://docs.faceping.ai/start/ios/).

## Run it

You need a Mac with Xcode 26 (or later) and an iPhone (iOS 15.1 or later) with a cable. The simulator has no front camera, so the face checks need a real iPhone.

1. **Get a free sandbox key** at [app.faceping.ai/signup](https://app.faceping.ai/signup) (no card, no approval). In the dashboard: **Developers → Sandbox keys → Create sandbox key**. It starts with `fp_test_`.
2. **Paste it** into a new file `Config/Local.xcconfig` (ignored by git, so your key stays out of commits):

   ```
   FACEPING_SANDBOX_KEY = fp_test_yourkey
   ```

   Or replace `fp_test_…` in `Config/FaceCheck.xcconfig`.
3. **Open `FaceCheck.xcodeproj`** in Xcode. It fetches the FacePing package from GitHub the first time.
4. **Set your team and bundle id**: select the FaceCheck target, **Signing & Capabilities**, pick your **Team**, and change the bundle identifier `com.yourcompany.facecheck` to your own. You can also put `DEVELOPMENT_TEAM = YOURTEAMID` in `Config/Local.xcconfig`.
5. **Run it on your iPhone** (choose it as the run destination, then **Run**). Allow the camera when asked. Xcode's **Run** makes a Debug build, which is several times slower at face checks: for real timings, edit the scheme (**Product → Scheme → Edit Scheme → Run → Build Configuration → Release**).
6. Tap **Enrol my face**, then **Verify**: you should see **Match**. Now switch on airplane mode and tap **Verify** again.

From the command line:

```bash
xcodebuild -project FaceCheck.xcodeproj -scheme FaceCheck -configuration Release -destination generic/platform=iOS \
  -allowProvisioningUpdates -derivedDataPath build DEVELOPMENT_TEAM=YOURTEAMID PRODUCT_BUNDLE_IDENTIFIER=com.yourcompany.facecheck
xcrun devicectl list devices      # your iPhone's identifier
xcrun devicectl device install app --device <identifier> build/Build/Products/Release-iphoneos/FaceCheck.app
```

## Try it as a check-in device

Once you've tried the server side with your sandbox key (a practice check-in list, an enrolment link, a device), this app can be the check-in device:

1. In the dashboard, open your practice list's **Devices** tab and add a device (or call `POST /v1/lists/{listId}/devices`). Copy the `fpd_` token.
2. In `Config/Local.xcconfig`, set the token and the person to verify (the `personId` you enrolled on the practice list, through an enrolment link or from your server):

   ```
   FACEPING_DEVICE_TOKEN = fpd_yourtoken
   FACEPING_PERSON_ID = ACME-000123
   ```

   With a device token set, the sandbox key is ignored. To keep the sandbox app on the phone as well, also set a different bundle id (for example `com.yourcompany.facecheck.device`).
3. Run it. The app downloads the list, hides **Enrol my face** (a check-in device gets its people from the server) and opens **Verify** once that person is on the phone. After each sync it says what it found: how many people, or that the token isn't valid, the list has finished, or it couldn't connect.

See [Devices and offline sync](https://docs.faceping.ai/devices/).

## What's where

| File | What it does |
|---|---|
| `FaceCheck/FaceCheckApp.swift` | Turns FacePing on with your sandbox key (`FacePing.configure(sandboxKey:)`), or a device token (`configure(deviceToken:)`), read from Info.plist. |
| `FaceCheck/ContentView.swift` | The screen: the camera view (`FaceCamera`), the result and the two buttons. |
| `FaceCheck/CheckModel.swift` | `enroll`, `verifyLive` and `sync`, and what each result means. `import Combine` is there because `ObservableObject` comes from Combine (new Xcode projects need the import). |
| `Config/FaceCheck.xcconfig` | Where the sandbox key (`FACEPING_SANDBOX_KEY`), or a device token (`FACEPING_DEVICE_TOKEN`) and person (`FACEPING_PERSON_ID`), are set, with `Config/Local.xcconfig` overriding them. |
| `FaceCheck/Info.plist` | `NSCameraUsageDescription` (the camera prompt), the key or token, and the person id. |
| `project.yml` | The [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec `FaceCheck.xcodeproj` was generated from. You don't need XcodeGen; it's there if you'd rather edit the spec and run `xcodegen`. |

The project depends on `https://github.com/faceping/faceping-ios` at exactly `1.0.0-preview.3`.

## The sandbox

Free, for building and testing: up to 25 faces per device, each deleted 24 hours after it was enrolled. Faces you enrol in the app never leave the phone. People on your practice list (see above) are held by FacePing, each for 24 hours. The app needs a connection the first time it runs, to activate your key; after that it works offline for 30 days.

To use FacePing with real people, go live from your [FacePing dashboard](https://app.faceping.ai). Your verify code doesn't change.

## Learn more

- [Get started on iOS](https://docs.faceping.ai/start/ios/)
- [How the SDK works](https://docs.faceping.ai/sdk/): liveness, storage, sandbox and production
- [FacePing for iOS](https://github.com/faceping/faceping-ios): the Swift package
- [Security](https://docs.faceping.ai/security/): the Rust core, encryption on the device
- Questions: support@faceping.ai

## Licence

This starter app is MIT licensed (see [LICENSE](LICENSE)): copy any of it into your own app. The FacePing SDK it uses has its own licence, in the [faceping-ios](https://github.com/faceping/faceping-ios) repo.
