import SwiftUI

/// Shown as a blocking, must-accept screen on first launch (and again if
/// `currentDisclaimerVersion` in HomeView is bumped), and available to re-read anytime
/// as a read-only sheet from the home screen.
struct DisclaimerView: View {
    /// Non-nil: shows an "I Understand & Agree" button and blocks dismissal until tapped
    /// (first-run acceptance). Nil: read-only, with a "Close" button (re-reading terms).
    var onAccept: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                // Compact layout: no hero icon/heading (the nav title covers it), body copy
                // at .subheadline, so the whole thing fits on one screen on most iPhones.
                VStack(alignment: .leading, spacing: 14) {
                    Text("""
                    Labelscope is a convenience tool. It searches text captured by your \
                    camera for the exact words you've added, using on-device text recognition \
                    (OCR).
                    """)

                    Group {
                        bullet("OCR can misread text that is blurry, small, glare-affected, handwritten, or in an unsupported language.")
                        bullet("It only looks for the words and common variations you specify \u{2014} it won't catch a word you haven't added, or one spelled or listed differently than expected.")
                        bullet("It cannot detect ingredient substitutions, recipe changes, or anything not printed on the label in front of it.")
                        bullet("A missed or incorrect match does not mean a word isn't present.")
                    }

                    Text("""
                    This app is not a substitute for reading labels yourself or verifying \
                    ingredients through other means \u{2014} always double-check anything that \
                    matters to you.
                    """)
                    .bold()

                    Text("""
                    By using this app, you acknowledge these limitations and agree that you \
                    use it at your own risk, and that its developer is not liable for any \
                    loss, harm, or other damage resulting from use of, or reliance on, this \
                    app.
                    """)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .padding()
            }
            // The accept button is pinned below the scroll view rather than placed at the
            // end of the text, so it's always fully visible (and never clipped by the home
            // indicator) no matter how tall the screen is — the text scrolls, the button
            // doesn't.
            .safeAreaInset(edge: .bottom) {
                if let onAccept {
                    Button(action: onAccept) {
                        Text("I Understand & Agree")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .foregroundColor(.white)
                    .background(LinearGradient.brandButton)
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(.bar)
                }
            }
            .navigationTitle("Before You Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onAccept == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        // First-run acceptance can't be swiped away without agreeing.
        .interactiveDismissDisabled(onAccept != nil)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
            Text(text)
        }
        .padding(.leading, 4)
    }
}

struct DisclaimerView_Previews: PreviewProvider {
    static var previews: some View {
        DisclaimerView(onAccept: {})
    }
}
