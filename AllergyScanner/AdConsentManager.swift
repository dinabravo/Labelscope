import Foundation
import GoogleMobileAds
import UserMessagingPlatform
import UIKit

/// Runs Google's User Messaging Platform (UMP) consent flow and gates all ad loading on
/// its result. Google requires a certified consent platform for users in the EEA / UK /
/// Switzerland before any ad can be served to them, so nothing here is optional:
///
/// 1. `gatherConsent()` is called once per launch (after the disclaimer has been
///    accepted, so the two full-screen presentations don't fight). It asks UMP whether
///    a consent form is needed for this user and, if so, presents it.
/// 2. Only after that does the Mobile Ads SDK get started, and `canRequestAds` flips
///    to `true`. `HomeView` doesn't create the banner until then, and
///    `InterstitialAdManager` skips loads until then.
/// 3. If UMP says the user is entitled to change their choice later
///    (`isPrivacyOptionsRequired`), `HomeView` shows a "Privacy Settings" link that
///    re-presents the form — also a Google requirement.
///
/// Outside the EEA, UMP reports "not required" almost immediately and ads start with no
/// visible UI. Any failure (offline, misconfigured message) is treated as "no consent
/// yet": the app keeps working, just without ads, and the next launch retries.
///
/// The message itself is configured in AdMob → Privacy & messaging → GDPR (the code
/// only requests and displays whatever is published there).
@MainActor
final class AdConsentManager: ObservableObject {
    static let shared = AdConsentManager()

    /// `true` once UMP says ads may be requested (consent obtained, or not required).
    @Published private(set) var canRequestAds = false
    /// `true` when the user must be given a way to revisit their consent choice.
    @Published private(set) var isPrivacyOptionsRequired = false

    private var isGathering = false
    private var hasStartedMobileAds = false

    private init() {}

    /// Requests the latest consent status from UMP and presents the consent form if one
    /// is required. Safe to call repeatedly; concurrent calls are ignored.
    func gatherConsent() async {
        guard !isGathering else { return }
        isGathering = true
        defer { isGathering = false }

        let parameters = RequestParameters()
        #if DEBUG
        // Force the EEA flow on registered test devices so the consent form can actually
        // be seen and tested from outside the EU. Ignored on non-test devices.
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        debugSettings.testDeviceIdentifiers = AdTestDevices.identifiers
        parameters.debugSettings = debugSettings
        #endif

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            // Returning users who already consented can start ads before the (unneeded)
            // form check finishes, so the banner isn't delayed on every launch.
            refreshState()
            try await ConsentForm.loadAndPresentIfRequired(from: UIApplication.keyRootViewController)
        } catch {
            // Offline, or the GDPR message isn't published yet in AdMob. Not fatal — the
            // app just runs ad-free until the next launch retries.
            print("[AdConsent] consent flow failed: \(error.localizedDescription)")
        }

        refreshState()
    }

    /// Re-opens the consent form so the user can change their choice. Only meaningful
    /// when `isPrivacyOptionsRequired` is `true`.
    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: UIApplication.keyRootViewController)
        } catch {
            print("[AdConsent] privacy options form failed: \(error.localizedDescription)")
        }
        refreshState()
    }

    private func refreshState() {
        let info = ConsentInformation.shared
        isPrivacyOptionsRequired = info.privacyOptionsRequirementStatus == .required
        canRequestAds = info.canRequestAds
        if canRequestAds { startMobileAdsIfNeeded() }
    }

    /// Starts the Google Mobile Ads SDK exactly once, and only after consent is settled.
    private func startMobileAdsIfNeeded() {
        guard !hasStartedMobileAds else { return }
        hasStartedMobileAds = true
        #if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = AdTestDevices.identifiers
        #endif
        MobileAds.shared.start()
    }
}

/// Device IDs that should receive **test** ads in Debug builds. Tapping real ads in your
/// own app is invalid traffic and gets AdMob accounts suspended, so register every phone
/// you develop on here.
///
/// To find a device's ID: run a Debug build on it, then search the Xcode console for
/// `testDeviceIdentifiers` — the SDK prints the exact hashed string to paste here. (The
/// same ID is used by both the Ads SDK and the UMP consent SDK.)
///
/// Release / TestFlight builds ignore this list; for those, register the phone in
/// AdMob → Settings → Test devices instead.
enum AdTestDevices {
    static let identifiers: [String] = [
        // "2077ef9a63d2b398840261c8221a0c9b",  // e.g. Dina's iPhone
    ]
}

extension UIApplication {
    /// The root view controller of the key window — the presenter for UMP forms and
    /// interstitials.
    static var keyRootViewController: UIViewController? {
        shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
