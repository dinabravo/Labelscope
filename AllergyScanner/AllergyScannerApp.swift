//
//  AllergyScannerApp.swift
//  AllergyScanner
//
//  Created by Dina Bravo Stojakovic on 10/06/2025.
//

import SwiftUI

@main
struct AllergyScannerApp: App {
    // The Google Mobile Ads SDK is deliberately *not* started here. AdConsentManager
    // starts it once the UMP consent flow has run (see HomeView), as Google requires.
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
