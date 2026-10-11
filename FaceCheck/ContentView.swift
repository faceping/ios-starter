import FacePing
import SwiftUI

/// The same screen as the MAUI and Android FaceCheck: the camera with the result over its bottom edge, then Enrol my
/// face and Verify (only Verify on a check-in device). The pill says whether the phone has a network (the checks never need one).
struct ContentView: View {
    @StateObject private var model = CheckModel()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("FaceCheck")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.ink)
                Spacer()
                Text(model.offline ? "Offline" : "Online")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(model.offline ? .amber : .slate)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(model.offline ? Color.pillOffline : Color.pill))
                    .accessibilityLabel(model.offline ? "No network" : "Network available")
            }
            .padding(.horizontal, 2)
            .padding(.top, 6)

            ZStack(alignment: .bottom) {
                FaceCamera(model.camera)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(model.tone.color)
                    Text(model.note)
                        .font(.system(size: 14))
                        .foregroundColor(.slate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.96)))
                .padding(12)
                .accessibilityElement(children: .combine)
            }
            .background(Color.cameraBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // On a check-in device people enrol on your server, so there's only Verify.
            if model.canEnroll {
                Button(action: model.enroll) {
                    Text(model.enrolled ? "Enrol again" : "Enrol my face")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.brand)
                .disabled(model.busy)
            }

            Button(action: model.verify) {
                Text("Verify")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.brand)
            .disabled(model.busy || !model.enrolled)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
        .task { await model.start() }
    }
}

extension CheckModel.Tone {
    var color: Color {
        switch self {
        case .ink: return .ink
        case .green: return .okGreen
        case .red: return .errorRed
        }
    }
}

extension Color {
    static let ink = Color(red: 0x0F / 255, green: 0x17 / 255, blue: 0x2A / 255)
    static let slate = Color(red: 0x47 / 255, green: 0x55 / 255, blue: 0x69 / 255)
    static let okGreen = Color(red: 0x04 / 255, green: 0x78 / 255, blue: 0x57 / 255)
    static let errorRed = Color(red: 0xB9 / 255, green: 0x1C / 255, blue: 0x1C / 255)
    static let amber = Color(red: 0xB4 / 255, green: 0x53 / 255, blue: 0x09 / 255)
    static let pill = Color(red: 0xEA / 255, green: 0xEC / 255, blue: 0xF0 / 255)
    static let pillOffline = Color(red: 0xFF / 255, green: 0xF4 / 255, blue: 0xE5 / 255)
    static let brand = Color(red: 0x25 / 255, green: 0x63 / 255, blue: 0xEB / 255)
    static let cameraBackground = Color(red: 0x0B / 255, green: 0x12 / 255, blue: 0x20 / 255)
}
