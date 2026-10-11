import Combine
import FacePing
import Network
import SwiftUI

/// The FaceCheck screen's state: enrol your face, then verify it with a live check, with or without a network. As a
/// check-in device (a device token in Config/Local.xcconfig), it verifies the person set as FACEPING_PERSON_ID once
/// they've synced from your practice list.
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

    /// Who to enrol and verify: "me" in the sandbox; on a check-in device, the personId you enrolled on the server.
    let personId: String = {
        let id = (Bundle.main.object(forInfoDictionaryKey: "FacePingPersonId") as? String ?? "").trimmingCharacters(in: .whitespaces)
        return id.isEmpty ? "me" : id
    }()

    private let faceping = FacePing.shared
    private let monitor = NWPathMonitor()
    private var started = false
    private var syncWatch: Task<Void, Never>?

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
        syncWatch?.cancel()
    }

    /// A face enrolled earlier may still be on the phone (sandbox faces are deleted 24 hours after enrolment).
    func start() async {
        guard !started else { return }
        started = true
        guard let faceping else {
            show("Setup problem", "Set your sandbox key (fp_test_…) or a device token (fpd_…) in Config/Local.xcconfig.", .red)
            canEnroll = false
            return
        }
        // A check-in device gets its people from the server: no enrolling here.
        canEnroll = faceping.isSandbox
        if !faceping.isSandbox {
            show("Syncing", "Downloading this list's people…", .ink)
            // Every sync after this one (automatic, every 5 minutes) updates the screen too.
            syncWatch = Task { [weak self] in
                for await result in faceping.synced {
                    self?.synced(result)
                }
            }
        }
        do {
            let result = try await faceping.sync()
            if !faceping.isSandbox { synced(result) }
        } catch FacePingError.setup(let message) {
            show(faceping.isSandbox ? "Sandbox key problem" : "Device token problem", message, .red)
        } catch FacePingError.model(let message) {
            show("Face check unavailable", message, .red)
        } catch {
            show("Try again", error.localizedDescription, .red)
        }
        setEnrolled(faceping.enrolledIds.contains(personId))
    }

    /// On a check-in device: open Verify once the person is here, and say what the sync found.
    private func synced(_ result: SyncResult) {
        guard let faceping else { return }
        let here = faceping.enrolledIds.contains(personId)
        setEnrolled(here)
        switch result.status {
        case .revoked:
            show("Device token not valid", "It was revoked or mistyped, or its list was deleted. Add the device again and use the new token.", .red)
        case .gone:
            show("List finished", "This list's faces have been deleted, so there's no one to check.", .ink)
        case .unavailable:
            show("Couldn't sync", "No connection to FacePing. The people synced before still work until the lease runs out.", .ink)
        default:
            show("\(result.enrolled) people synced",
                 here ? "\(personId) is here: tap Verify." : "\(personId) isn't on this list yet. Enrol them on your server, then reopen the app.", .ink)
        }
    }

    func enroll() {
        run { faceping in
            self.show("Hold still", "Taking the photo…", .ink)
            self.camera.guideState = .working
            let photo = try await self.camera.capture()
            let result = try await faceping.enroll(id: self.personId, photo: photo)
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
            let result = try await faceping.verifyLive(id: self.personId, camera: self.camera)
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
                show(faceping.isSandbox ? "Sandbox key problem" : "Device token problem", message, .red)
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
            setEnrolled(faceping.enrolledIds.contains(personId))
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
