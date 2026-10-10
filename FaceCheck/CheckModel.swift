import FacePing
import Network
import SwiftUI

/// The FaceCheck screen's state: enrol your face, then verify it with a live check, with or without a network.
@MainActor
final class CheckModel: ObservableObject {
    enum Tone { case ink, green, red }

    let camera = FaceCameraView()
    @Published var title = "Look at the camera"
    @Published var note = "Tap Enrol my face to start."
    @Published var tone = Tone.ink
    @Published var enrolled = false
    @Published var busy = false
    @Published var offline = false
    @Published var canEnroll = true

    private let faceping = FacePing.shared
    private let monitor = NWPathMonitor()
    private var started = false

    init() {
        camera.onCameraFailed = { [weak self] message in self?.show("Camera unavailable", message, .ink) }
        monitor.pathUpdateHandler = { [weak self] path in
            let off = path.status != .satisfied
            Task { @MainActor in self?.offline = off }
        }
        monitor.start(queue: DispatchQueue(label: "FaceCheck.network"))
    }

    deinit {
        monitor.cancel()
    }

    /// A face enrolled earlier may still be on the phone (sandbox faces are deleted 24 hours after enrolment).
    func start() async {
        guard !started else { return }
        started = true
        guard let faceping else {
            show("Sandbox key problem", "Set your sandbox key in Config/Local.xcconfig or Config/FaceCheck.xcconfig (it starts with fp_test_).", .red)
            canEnroll = false
            return
        }
        do {
            try await faceping.sync()
        } catch FacePingError.setup(let message) {
            show("Sandbox key problem", message, .red)
        } catch FacePingError.model(let message) {
            show("Face check unavailable", message, .red)
        } catch {
            show("Try again", error.localizedDescription, .red)
        }
        setEnrolled(faceping.enrolledIds.contains("me"))
    }

    func enroll() {
        run { faceping in
            self.show("Hold still", "Taking the photo…", .ink)
            self.camera.guideState = .working
            let photo = try await self.camera.capture()
            let result = try await faceping.enroll(id: "me", photo: photo)
            self.camera.guideState = .ready
            if result.isEnrolled {
                self.setEnrolled(true)
                self.show("Enrolled", self.offline ? "No network. Tap Verify." : "Now tap Verify.", .ink)
            } else {
                self.show("Try again", Self.describe(result.outcome), .red)
            }
        }
    }

    func verify() {
        run { faceping in
            self.show("Turn your head", "Liveness check…", .ink)
            // A live check: matches your face, asks you to turn your head (liveness), then matches again.
            let result = try await faceping.verifyLive(id: "me", camera: self.camera)
            let time = String(format: "%.2f s", result.elapsed)
            if result.isMatch {
                self.show("Match", "Live face · \(time) · \(self.offline ? "no network used" : "on the phone")", .green)
            } else {
                self.show(Self.title(result.outcome), "Tap Verify to try again.", .red)
            }
        }
    }

    private func run(_ action: @escaping (FacePing) async throws -> Void) {
        guard !busy, let faceping else { return }
        busy = true
        Task {
            do {
                try await action(faceping)
            } catch FacePingError.setup(let message) {
                // The sandbox key is missing or revoked, or the very first run had no connection.
                camera.guideState = .ready
                show("Sandbox key problem", message, .red)
            } catch FacePingError.model(let message) {
                // The face models couldn't load on this phone: send people to your normal way in.
                camera.guideState = .ready
                show("Face check unavailable", message, .red)
            } catch {
                // For example the camera didn't deliver a picture.
                camera.guideState = .ready
                show("Try again", error.localizedDescription, .red)
            }
            busy = false
            setEnrolled(faceping.enrolledIds.contains("me"))
        }
    }

    private func setEnrolled(_ value: Bool) {
        enrolled = value
    }

    private func show(_ title: String, _ note: String, _ tone: Tone) {
        self.title = title
        self.note = note
        self.tone = tone
    }

    static func title(_ outcome: VerifyOutcome) -> String {
        switch outcome {
        case .noMatch: return "Not a match"
        case .notEnrolled: return "Not enrolled"
        case .noFace: return "No face seen"
        case .livenessFailed: return "Not a live face"
        case .challengeFailed: return "Head turn not seen"
        case .expired: return "Enrolment expired"
        case .leaseExpired: return "Sync needed"
        case .match: return "Match"
        @unknown default: return "Try again"
        }
    }

    static func describe(_ outcome: EnrollOutcome) -> String {
        switch outcome {
        case .noFace: return "No face seen. Look at the camera."
        case .multipleFaces: return "More than one face. Just you, please."
        case .faceTooSmall: return "Move a little closer."
        case .notLive: return "That looked like a photo or a screen."
        case .limitReached: return "The sandbox is full on this phone."
        case .enrolled: return "Enrolled."
        @unknown default: return "Tap Enrol my face to try again."
        }
    }
}
