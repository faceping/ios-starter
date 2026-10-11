import FacePing
import os
import SwiftUI

@main
struct FaceCheckApp: App {
    init() {
        // Starts loading the face models in the background, so the first check is quick. With a device token (set in
        // Config/Local.xcconfig), this phone is a check-in device for one list; otherwise it runs the sandbox.
        let info = Bundle.main.infoDictionary ?? [:]
        let token = (info["FacePingDeviceToken"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let key = info["FacePingSandboxKey"] as? String ?? ""
        do {
            if token.isEmpty {
                try FacePing.configure(sandboxKey: key)
            } else {
                try FacePing.configure(deviceToken: token)
            }
        } catch {
            // A missing or malformed key or token: the screen shows the message.
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "FaceCheck", category: "FaceCheck").warning("FacePing setup: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
