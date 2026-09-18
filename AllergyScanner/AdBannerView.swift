import SwiftUI
import GoogleMobileAds

/// A SwiftUI wrapper around a Google Mobile Ads adaptive banner.
///
/// Uses the real AdMob "Home banner" unit. Your own phone must be registered as a test
/// device (see `AllergyScannerApp`) so it gets test creatives — tapping real ads on your
/// own app counts as invalid traffic. The ad is only requested once the user has been
/// through the GDPR consent flow (`AdConsentManager.canRequestAds`).
struct AdBannerView: UIViewRepresentable {
    /// Reports the loaded ad's actual height back to the caller, since adaptive banners
    /// aren't a fixed size — the caller should apply this as the container's frame height.
    @Binding var height: CGFloat

    private let adUnitID = "ca-app-pub-9415344326902270/3516667583" // AdMob: Labelscope → Home banner

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.keyRootViewController
        banner.delegate = context.coordinator
        banner.adSize = largeAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let height: Binding<CGFloat>

        init(height: Binding<CGFloat>) {
            self.height = height
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            height.wrappedValue = bannerView.adSize.size.height
        }
    }
}
