import Foundation
import CloudKit
import SwiftUI

/// Manages the "Force Update" gate.
///
/// On launch it reads a single record from the CloudKit **public** database
/// (record type `AppConfig`, record name `appConfig`) and compares the installed
/// app version against the `minimumVersion` value stored there. If the installed
/// version is older, `updateRequired` becomes true and the app shows a blocking
/// `ForceUpdateView`.
///
/// To force everyone off an old version in the future, just edit the `minimumVersion`
/// field of that record in CloudKit Dashboard — no new app release is needed.
@Observable
@MainActor
final class ForceUpdateManager {
    static let shared = ForceUpdateManager()

    /// True when the installed version is older than the required minimum from CloudKit.
    var updateRequired = false
    /// Optional custom message shown on the blocking screen (from CloudKit `updateMessage`).
    var updateMessage: String?
    /// The App Store URL opened when the user taps "Update".
    var appStoreURL: URL?

    // MARK: - Configuration

    /// The app's numeric App Store ID (e.g. "1234567890").
    /// Find it in App Store Connect → your app → General → App Information → "Apple ID".
    /// The CloudKit record can also override the full link via the `appStoreURL` field,
    /// so you can fix or change the link later without shipping an update.
    private let appStoreID = "6759262245"

    private let database = CKContainer(identifier: "iCloud.com.yonatan.recipeapp").publicCloudDatabase
    private let configRecordID = CKRecord.ID(recordName: "appConfig")

    private init() {}

    /// The currently installed short version string, e.g. "1.0".
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Check

    /// Fetches the remote config and decides whether an update is required.
    /// Fails open: if the record is missing or the network fails, the user is never blocked.
    func checkForRequiredUpdate() async {
        // Default App Store link built from the numeric ID (may be overridden below).
        if !appStoreID.isEmpty {
            appStoreURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)")
        }

        do {
            let record = try await database.record(for: configRecordID)

            if let remoteMessage = record["updateMessage"] as? String, !remoteMessage.isEmpty {
                updateMessage = remoteMessage
            }
            // Allow the link to be controlled remotely as well.
            if let remoteURLString = record["appStoreURL"] as? String,
               let remoteURL = URL(string: remoteURLString) {
                appStoreURL = remoteURL
            }

            let minimumVersion = record["minimumVersion"] as? String ?? "0"
            if isVersion(currentVersion, olderThan: minimumVersion) {
                print("⛔️ Force update required. Installed \(currentVersion) < minimum \(minimumVersion)")
                updateRequired = true
            } else {
                print("✅ Version OK. Installed \(currentVersion), minimum \(minimumVersion)")
            }
        } catch {
            // Record not found / offline / any error → never block the user.
            print("ℹ️ Force-update check skipped: \(error.localizedDescription)")
        }
    }

    /// Component-wise version comparison. Returns true when `current` is strictly
    /// older than `minimum` (e.g. "1.9" is older than "1.10").
    private func isVersion(_ current: String, olderThan minimum: String) -> Bool {
        let currentParts = current.split(separator: ".").map { Int($0) ?? 0 }
        let minimumParts = minimum.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(currentParts.count, minimumParts.count)
        for index in 0..<count {
            let c = index < currentParts.count ? currentParts[index] : 0
            let m = index < minimumParts.count ? minimumParts[index] : 0
            if c < m { return true }
            if c > m { return false }
        }
        return false
    }
}
