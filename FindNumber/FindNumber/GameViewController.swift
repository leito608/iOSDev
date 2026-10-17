//
//  GameViewController.swift
//  FindNumber
//
//  Created by Jukchai Sengboonleng on 15/10/26.
//

import UIKit
import SpriteKit
import GoogleMobileAds

class GameViewController: UIViewController, GADBannerViewDelegate {
    private weak var gameScene: GameScene?
    private var bannerView: GADBannerView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let view = self.view as? SKView else { return }

        view.ignoresSiblingOrder = true

        GADMobileAds.sharedInstance().start(completionHandler: nil)

        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        scene.onGameCompletionChanged = { [weak self] isComplete in
            if isComplete {
                self?.showBannerAd()
            } else {
                self?.removeBannerAd()
            }
        }
        gameScene = scene
        view.presentScene(scene)
    }

    private func showBannerAd() {
        guard bannerView == nil else { return }

        let banner = GADBannerView(adSize: GADAdSizeBanner)
        //banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #if DEBUG
        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"   // Google test banner
        #else
        banner.adUnitID = "ca-app-pub-8986836930601743/4136449801"
        #endif
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            banner.widthAnchor.constraint(equalToConstant: 320),
            banner.heightAnchor.constraint(equalToConstant: 50)
        ])
        bannerView = banner
        banner.load(GADRequest())
    }

    private func removeBannerAd() {
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("Google Mobile Ads banner failed to load: \(error.localizedDescription)")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSceneLayout()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateSceneLayout()
    }

    private func updateSceneLayout() {
        guard let view = self.view as? SKView, let scene = gameScene else { return }
        scene.updateSafeAreaInsets(view.safeAreaInsets)
        if scene.size != view.bounds.size {
            scene.size = view.bounds.size
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
