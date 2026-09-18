import SwiftUI
import AVFoundation

struct ScannerView: View {
    @ObservedObject var scanner: TextScannerService
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // this uses CameraPreview.swift — the preview layer itself draws the
            // match-highlight boxes, since only it knows the exact video-to-screen mapping.
            CameraPreview(session: scanner.getSession(), matchedBoxes: scanner.matchedBoxes)
                .ignoresSafeArea()

            // Dismiss button, match badges, and the reminder banner stack in normal flow
            // (respecting the safe area, so they clear the notch/Dynamic Island and the
            // home indicator).
            VStack(spacing: 12) {
                topBar

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(scanner.detectedMatches) { match in
                            matchBadge(match)
                        }
                    }
                    .padding(.trailing)
                }

                Spacer()

                reminderBanner
                    .padding(.bottom, 8)
            }
        }
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .environment(\.colorScheme, .dark)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var reminderBanner: some View {
        Text("Results may be incomplete \u{2014} double-check labels yourself")
            .font(.caption2.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
    }

    private func matchBadge(_ match: AllergenMatch) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Label(match.allergen, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
            if !match.isDirectMatch {
                Text("found: \(match.matchedPhrase)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.warning.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
    }
}
