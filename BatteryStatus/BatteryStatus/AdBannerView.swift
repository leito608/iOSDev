import SwiftUI
import GoogleMobileAds

/// Ad unit IDs.
/// While you build and test from Xcode (Debug), the app uses Google's TEST
/// banner ID, so you never show or click real ads by accident.
/// Replace the second ID with your own ad unit ID from AdMob before releasing.
/// An AD UNIT ID contains a "/" (slash). An APP ID contains a "~" (tilde).
enum AdConfig {
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-8986836930601743~4401239349"   // Google test banner
    #else
    static let bannerUnitID = "ca-app-pub-8986836930601743~4401239349"   // YOUR real banner ad unit ID
    #endif
}

/// A banner ad you can place anywhere in a SwiftUI screen.
/// In Debug builds, a small line of text under the banner tells you
/// whether the ad loaded or why it failed.
struct AdBannerView: View {
    @State private var status = "Loading ad..."

    private var adSize: AdSize {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let width = scene?.screen.bounds.width ?? 375
        return currentOrientationAnchoredAdaptiveBanner(width: width)
    }

    var body: some View {
        VStack(spacing: 2) {
            BannerContainer(adSize: adSize) { message in
                status = message
            }
            .frame(width: adSize.size.width, height: adSize.size.height)

            #if DEBUG
            Text(status)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            #endif
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adSize: AdSize
    let onStatus: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatus: onStatus)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // The window may not exist yet when the banner is first created.
        if uiView.rootViewController == nil {
            uiView.rootViewController = Self.topViewController()
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        let onStatus: (String) -> Void
        init(onStatus: @escaping (String) -> Void) { self.onStatus = onStatus }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            DispatchQueue.main.async { self.onStatus("Ad loaded") }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner failed: \(error)")
            DispatchQueue.main.async {
                self.onStatus("Ad failed: \(error.localizedDescription)")
            }
        }
    }
}
