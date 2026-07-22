import Foundation
import Dependencies
import RevenueCat // SPM: https://github.com/RevenueCat/purchases-ios (add to the app target)

/// RevenueCat wrapper, in the app's swift-dependencies style.
///
/// Purchases happen on-device (App Store / StoreKit). The backend is the
/// entitlement source of truth via the RevenueCat webhook, so after a purchase
/// you can either read `isPro` here or refetch `/v1/me` from the backend.
public struct BillingClient: Sendable {
  /// Call once at app launch with your RevenueCat PUBLIC SDK key (test_… / appl_…).
  public var configure: @Sendable (_ apiKey: String) -> Void
  /// Link the RevenueCat user to the Cadence account id (from `/auth/*`). Do this
  /// right after login so webhook events map to the right backend user.
  public var logIn: @Sendable (_ cadenceUserID: String) async -> Void
  public var logOut: @Sendable () async -> Void
  public var isPro: @Sendable () async -> Bool
  public var currentOffering: @Sendable () async throws -> [Package]
  /// Returns true if the user is Pro after purchasing.
  public var purchase: @Sendable (_ package: Package) async throws -> Bool
  public var restore: @Sendable () async throws -> Bool
}

public extension BillingClient {
  /// Must match the entitlement id configured in RevenueCat and the backend's
  /// REVENUECAT_ENTITLEMENT_PLANS (defaults to "pro").
  static let entitlementID = "pro"

  static func live() -> BillingClient {
    BillingClient(
      configure: { apiKey in
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
      },
      logIn: { cadenceUserID in _ = try? await Purchases.shared.logIn(cadenceUserID) },
      logOut: { _ = try? await Purchases.shared.logOut() },
      isPro: {
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return info.entitlements[entitlementID]?.isActive == true
      },
      currentOffering: {
        let offerings = try await Purchases.shared.offerings()
        return offerings.current?.availablePackages ?? []
      },
      purchase: { package in
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo.entitlements[entitlementID]?.isActive == true
      },
      restore: {
        let info = try await Purchases.shared.restorePurchases()
        return info.entitlements[entitlementID]?.isActive == true
      }
    )
  }
}

extension BillingClient: DependencyKey {
  public static let liveValue = BillingClient.live()
}

public extension DependencyValues {
  var billing: BillingClient {
    get { self[BillingClient.self] }
    set { self[BillingClient.self] = newValue }
  }
}
