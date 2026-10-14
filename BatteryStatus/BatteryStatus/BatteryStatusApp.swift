//
//  BatteryStatusApp.swift
//  BatteryStatus
//
//  Created by Jukchai Sengboonleng on 14/10/26.
//

import SwiftUI
import GoogleMobileAds

@main
struct BatteryStatusApp: App {
    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
