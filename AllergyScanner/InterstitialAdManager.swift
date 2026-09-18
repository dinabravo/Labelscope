import Foundation
import GoogleMobileAds
import UIKit

/// Loads and presents a Google Mobile Ads interstitial (full-screen ad) at throttled
/// intervals, so the Remove Ads purchase has something to remove beyond a banner.
///
/// The interstitial is shown when the user *closes* the scanner — never before or during
/// a scan (that's the one moment the user actually needs the app, and blocking it is both
/// hostile and against AdMob's interstitial guidance). Frequency is capped two ways: skip
/// the first few scanner closes, then only every Nth close *and* only if enough time has
/// passed since the last one — see the constants below.
///
/// Uses the real AdMob "Scanner close" unit. Loads are skipped until the GDPR consent
/// flow has completed (`AdConsentManager.canRequestAds`).
@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    private let adUnitID = "ca-app-pub-9415344326902270/3927731128" // AdMob: Labelscope → Scanner close

    // MARK: Frequency cap

    /// Don't show any interstitial for this many scanner closes after launch, so a
    /// brand-new user gets a feel for the app before being interrupted.
    private let freeScansPerLaunch = 2
    /// After that, show at most one interstitial per this many scanner closes.
    private let scansBetweenAds = 3
    /// ...and never more often than this, regardless of how fast the user scans.
    private let minimumInterval: TimeInterval = 3 * 60

    private var scannerCloseCount = 0
    private var lastShownDate = Date.distantPast
    private var closesSinceLastAd = 0

    private var interstitial: InterstitialAd?
    private var isLoading = false

    /// Called whenever the scanner is dismissed. Presents an interstitial if one is due
    /// (and loaded), otherwise just updates the counters and preloads for next time.
    /// Does nothing at all once the user has bought Remove Ads.
    func scannerDidClose(adsRemoved: Bool) {
        guard !adsRemoved else {
            interstitial = nil
            return
        }

        scannerCloseCount += 1
        closesSinceLastAd += 1

        // Kick off the first load lazily so no ad traffic happens until it's needed.
        if interstitial == nil { preload() }

        guard scannerCloseCount > freeScansPerLaunch,
              closesSinceLastAd >= scansBetweenAds,
              Date().timeIntervalSince(lastShownDate) >= minimumInterval,
              let ad = interstitial,
              let rootVC = UIApplication.keyRootViewController
        else { return }

        interstitial = nil
        lastShownDate = Date()
        closesSinceLastAd = 0
        ad.fullScreenContentDelegate = self
        ad.present(from: rootVC)
    }

    /// Loads the next interstitial in the background so it's ready to present instantly.
    private func preload() {
        guard !isLoading, interstitial == nil, AdConsentManager.shared.canRequestAds else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                interstitial = try await InterstitialAd.load(with: adUnitID, request: Request())
            } catch {
                // Not fatal — no fill or no network just means no ad this time. The next
                // scanner close will retry.
                interstitial = nil
            }
        }
    }

}

// MARK: - FullScreenContentDelegate

extension InterstitialAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Interstitials are single-use; line up the next one as soon as this one closes.
        preload()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // Don't burn the cooldown on an ad that never actually showed.
        lastShownDate = .distantPast
        preload()
    }
}
