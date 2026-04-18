//
//  NotificationManager.swift
//  Sortala
//

import UserNotifications

/// Manages local deadline reminder notifications.
/// HIG: "Use notifications to share genuinely important or timely information."
enum NotificationManager {
    // MARK: - Permission

    /// Checks current authorization status.
    static func checkStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Requests notification permission. Returns true if granted.
    /// Called on first order save so the user understands WHY (context-driven).
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// Schedules a reminder 1 hour before the order deadline.
    /// Only schedules if notification permission is authorized.
    static func scheduleDeadlineReminder(for order: Order) async {
        let status = await checkStatus()
        guard status == .authorized || status == .provisional else { return }
        
        let triggerDate = order.deadline.addingTimeInterval(-3600)
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Deadline: \(order.customerName)"
        content.body = order.itemsSummary
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: order.id.uuidString,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    /// Cancels a pending reminder. Called when order is completed or deleted.
    static func cancelReminder(for order: Order) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [order.id.uuidString]
            )
    }

    // MARK: - Badge

    /// Clears the app icon badge count. Call when app becomes active.
    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
