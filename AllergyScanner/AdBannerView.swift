import SwiftUI
import GoogleMobileAds

/// A SwiftUI wrapper around a Google Mobile Ads adaptive banner.
///
/// Uses Google's official TEST ad unit ID (safe to ship in Debug builds — it always fills
/// with a placeholder ad and never affects your AdMob account). **Replace `adUnitID` with
/// your real AdMob banner unit ID before submitting a release build**, or ads will keep
/// serving test creatives in production.
struct AdBannerView: UIViewRepresentable {
    /// Reports the loaded ad's actual height back to the caller, since adaptive banners
    /// aren't a fixed size — the caller should apply this as the container's frame height.
    @Binding var height: CGFloat

    private let adUnitID = "ca-app-pub-3940256099942544/2435281174" // Google TEST banner unit ID

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.rootViewController = Self.rootViewController()
        banner.delegate = context.coordinator
        banner.adSize = largeAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
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
