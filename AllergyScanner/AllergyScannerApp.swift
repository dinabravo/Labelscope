//
//  AllergyScannerApp.swift
//  AllergyScanner
//
//  Created by Dina Bravo Stojakovic on 10/06/2025.
//

import SwiftUI
import GoogleMobileAds

@main
struct AllergyScannerApp: App {
    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
