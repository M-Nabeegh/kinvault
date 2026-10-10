import Foundation
import KinVaultCore
import UserNotifications

/// Local expiry reminders, scheduled by macOS on this Mac. Off until the person turns them on.
enum Reminders {
    static let enabledKey = "remindersEnabled"
    static let leadDaysKey = "reminderLeadDays"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var leadDays: Int {
        let value = UserDefaults.standard.integer(forKey: leadDaysKey)
        return value == 0 ? 30 : value
    }

    private static var center: UNUserNotificationCenter? {
        // Notifications need a real app bundle; `swift run` builds don't have one.
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    static func requestPermission() async -> Bool {
        guard let center else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(for document: VaultDocument) {
        guard let center else { return }
        let id = document.id
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        guard isEnabled, let expiry = document.expiryDate,
              let fireDate = DateReader.calendar.date(byAdding: .day, value: -leadDays, to: expiry),
              fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        let owner = document.holderName.isEmpty ? "" : "\(document.holderName)’s "
        content.title = "\(owner)\(document.title.lowercased()) expires soon"
        content.body = "It expires on \(expiry.formatted(date: .long, time: .omitted)). Open KinVault to see the details."
        content.sound = .default

        var parts = DateReader.calendar.dateComponents([.year, .month, .day], from: fireDate)
        parts.hour = 9
        let request = UNNotificationRequest(
            identifier: id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        center.add(request)
    }

    static func rescheduleAll(_ documents: [VaultDocument]) {
        cancelAll()
        documents.forEach(schedule(for:))
    }

    static func cancel(for id: UUID) {
        center?.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    static func cancelAll() {
        center?.removeAllPendingNotificationRequests()
    }
}
