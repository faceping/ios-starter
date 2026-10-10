import FacePing
import os
import SwiftUI

@main
struct FaceCheckApp: App {
    init() {
        // Starts loading the face models in the background, so the first check is quick.
        let key = Bundle.main.object(forInfoDictionaryKey: "FacePingSandboxKey") as? String ?? ""
        do {
            try FacePing.configure(sandboxKey: key)
        } catch {
            // A missing or malformed key: the screen shows the message.
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "FaceCheck", category: "FaceCheck").warning("FacePing setup: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
