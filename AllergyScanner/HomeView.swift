//
//  HomeView.swift
//  AllergyScanner
//
//  Created by Dina Bravo Stojakovic on 10/06/2025.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @StateObject private var scanner = TextScannerService()
    @StateObject private var purchaseManager = PurchaseManager()
    @StateObject private var interstitialAds = InterstitialAdManager()

    @State private var newAllergen = ""
    @State private var showingScanner = false
    @State private var adHeight: CGFloat = 50
    @FocusState private var fieldFocused: Bool

    // Bump this if the disclaimer wording materially changes, to force re-acceptance.
    private let currentDisclaimerVersion = 2
    @AppStorage("acceptedDisclaimerVersion") private var acceptedDisclaimerVersion = 0
    @State private var showingOnboardingDisclaimer = false
    @State private var showingDisclaimer = false

    private var canAdd: Bool {
        !newAllergen.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    addField
                        .padding(.horizontal)
                        .padding(.top, 18)

                    if vm.allergens.isEmpty {
                        emptyState
                    } else {
                        allergenList
                    }

                    scanButton
                        .padding(.horizontal)
                        .padding(.top, 12)

                    footerLinks
                        .padding(.vertical, 10)

                    if !purchaseManager.isAdRemovalPurchased {
                        AdBannerView(height: $adHeight)
                            .frame(height: adHeight)
                    }
                }
            }
            .navigationBarHidden(true)
            // Present the ScannerView as a sheet. Only the camera feed inside ScannerView
            // ignores the safe area (so it's edge-to-edge) — the top bar/dismiss button
            // still need normal safe-area insets so they clear the notch/Dynamic Island.
            // An interstitial ad may show on the way *out* of the scanner (throttled — see
            // InterstitialAdManager), never on the way in.
            .fullScreenCover(isPresented: $showingScanner, onDismiss: {
                interstitialAds.scannerDidClose(adsRemoved: purchaseManager.isAdRemovalPurchased)
            }) {
                ScannerView(scanner: scanner, isPresented: $showingScanner)
            }
        }
        .navigationViewStyle(.stack)
        // Blocking first-run (or post-update) acceptance of the disclaimer.
        .fullScreenCover(isPresented: $showingOnboardingDisclaimer) {
            DisclaimerView {
                acceptedDisclaimerVersion = currentDisclaimerVersion
                showingOnboardingDisclaimer = false
            }
        }
        // Read-only, dismissible re-read of the same terms.
        .sheet(isPresented: $showingDisclaimer) {
            DisclaimerView(onAccept: nil)
        }
        .onAppear {
            if acceptedDisclaimerVersion < currentDisclaimerVersion {
                showingOnboardingDisclaimer = true
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { purchaseManager.errorMessage != nil },
                set: { if !$0 { purchaseManager.errorMessage = nil } }
            )
        ) {
            Button("OK") { purchaseManager.errorMessage = nil }
        } message: {
            Text(purchaseManager.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var footerLinks: some View {
        VStack(spacing: 6) {
            Button("Disclaimer & Limitations") {
                showingDisclaimer = true
            }
            .foregroundColor(.secondary)

            if !purchaseManager.isAdRemovalPurchased {
                HStack(spacing: 16) {
                    Button(removeAdsLabel) {
                        Task { await purchaseManager.purchaseRemoveAds() }
                    }
                    Button("Restore Purchases") {
                        Task { await purchaseManager.restorePurchases() }
                    }
                }
                .foregroundColor(.brand)
            }
        }
        .font(.footnote)
    }

    private var removeAdsLabel: String {
        if let price = purchaseManager.product?.displayPrice {
            return "Remove Ads \u{2014} \(price)"
        }
        return "Remove Ads"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LabelLens")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Add the words you want to find on labels")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .foregroundColor(.secondary)
                .font(.subheadline)

            TextField("Add a keyword, e.g. palm oil", text: $newAllergen)
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(addAllergen)

            Button(action: addAllergen) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(canAdd ? .brand : Color(.tertiaryLabel))
            }
            .disabled(!canAdd)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardBackground(cornerRadius: 14)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No keywords yet")
                .font(.headline)
            Text("Add the words you want to find when scanning a label, like \u{201c}palm oil\u{201d} or \u{201c}red 40.\u{201d}")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var allergenList: some View {
        List {
            ForEach(vm.allergens, id: \.self) { allergen in
                allergenRow(allergen)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: vm.remove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    private func allergenRow(_ allergen: String) -> some View {
        HStack(spacing: 12) {
            // Neutral "this is a keyword" marker, echoing the tag icon in the add field.
            // Warning-red is reserved for actual matches on the scanner screen.
            ZStack {
                Circle().fill(Color.brand.opacity(0.12))
                Image(systemName: "tag.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.brand)
            }
            .frame(width: 30, height: 30)

            Text(allergen.capitalized)
                .font(.body.weight(.medium))

            Spacer()

            // Visible delete affordance — swipe-to-delete still works, but plenty of
            // people never discover it, so give them a button too.
            Button {
                withAnimation { vm.remove(allergen) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(allergen)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .cardBackground(cornerRadius: 14)
    }

    private var scanButton: some View {
        Button {
            fieldFocused = false
            // Sync allergens into scanner (lowercased)
            scanner.allergens = vm.allergens.map { $0.lowercased() }
            showingScanner = true
        } label: {
            Label("Scan Ingredients", systemImage: "camera.viewfinder")
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .foregroundColor(.white)
        .background(vm.allergens.isEmpty ? AnyView(Color.gray.opacity(0.5)) : AnyView(LinearGradient.brandButton))
        .cornerRadius(16)
        .disabled(vm.allergens.isEmpty)
    }

    private func addAllergen() {
        vm.add(newAllergen)
        newAllergen = ""
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
