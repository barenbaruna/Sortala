//
//  NotificationManager.swift
//  Sortala
//

import UserNotifications

/// Manages local deadline reminder notifications.
/// Apple HIG: "Use notifications to share genuinely important or timely information."
enum NotificationManager {
    // MARK: - Permission

    /// Requests notification permission. Called on first order save
    /// so the user understands WHY we need it (context-driven).
    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Schedule

    /// Schedules a reminder 1 hour before the order deadline.
    /// Uses `.timeSensitive` because deadlines are time-critical.
    static func scheduleDeadlineReminder(for order: Order) {
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

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    /// Cancels a pending reminder. Called when order is completed or deleted.
    static func cancelReminder(for order: Order) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [order.id.uuidString]
            )
    }
}
