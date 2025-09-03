import Foundation
import StoreKit
import SwiftData

enum PurchaseError: Error { case productNotFound, unverified }

final class PurchaseManager {
    static let shared = PurchaseManager()
    private init() {}

    // TODO: App Store Connect で作成した本番のプロダクトIDに置き換えてください
    // Auto-Renewable Subscription を想定
    let premiumProductId = "symptomemo.premium"

    // 現在のプレミアム権利を確認
    func hasPremiumEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let tx):
                if tx.productID == premiumProductId { return true }
            case .unverified:
                continue
            }
        }
        return false
    }

    // 設定モデルへ反映
    @MainActor
    func syncEntitlements(context: ModelContext) async {
        let isActive = await hasPremiumEntitlement()
        let fetch = FetchDescriptor<AppSettings>(predicate: nil, sortBy: [])
        let settings = (try? context.fetch(fetch)) ?? []
        let s = settings.first ?? {
            let obj = AppSettings()
            context.insert(obj)
            return obj
        }()
    s.isPremium = isActive
        // サブスク有効ならトライアルは終了扱い
    if isActive { s.isInTrial = false }
    else if let end = s.trialEndAt, end <= Date() { s.isInTrial = false }
        try? context.save()
    }

    // 購入
    func purchasePremium() async throws -> Bool {
        let products = try await Product.products(for: [premiumProductId])
        guard let product = products.first else { throw PurchaseError.productNotFound }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await tx.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    // 復元（サインイン・購入の復元を促す）
    func restore() async -> Bool {
        do { try await AppStore.sync() } catch { /* ignore */ }
        return await hasPremiumEntitlement()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.unverified
        case .verified(let safe):
            return safe
        }
    }
}
