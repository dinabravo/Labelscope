import Foundation
import StoreKit

/// Manages the one-time "Remove Ads" non-consumable in-app purchase via StoreKit 2.
///
/// Create a non-consumable In-App Purchase in App Store Connect with the exact product ID
/// `removeAdsProductID` below before this can load a real product or accept payment.
@MainActor
final class PurchaseManager: ObservableObject {
    static let removeAdsProductID = "com.dina.ingredientfinder.removeads"

    @Published private(set) var isAdRemovalPurchased = false
    @Published private(set) var product: Product?
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Listen for purchases/refunds/family-sharing changes made outside purchaseRemoveAds(),
        // e.g. from the App Store or another device.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            product = products.first
        } catch {
            errorMessage = "Couldn't load the Remove Ads product: \(error.localizedDescription)"
        }
    }

    func purchaseRemoveAds() async {
        guard let product else {
            errorMessage = "The Remove Ads product isn't available right now."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.removeAdsProductID {
                isAdRemovalPurchased = true
                return
            }
        }
        isAdRemovalPurchased = false
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        if transaction.productID == Self.removeAdsProductID {
            isAdRemovalPurchased = true
        }
        await transaction.finish()
    }
}
