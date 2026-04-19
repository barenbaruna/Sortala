//
//  NotificationManager.swift
//  Sortala
//

import os
import SwiftData
import UserNotifications

/// Manages local deadline reminder notifications.
/// HIG: "Use notifications to share genuinely important or timely information."
enum NotificationManager {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sortala", category: "Notifications")

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
        content.title = "Pengingat target: \(order.customerName)"
        content.body = "Pesanan \(order.itemsSummary) memiliki tenggat waktu 1 jam lagi."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.badge = 1

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

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Successfully scheduled reminder for order: \(order.id.uuidString)")
        } catch {
            logger.error("Failed to schedule deadline reminder for \(order.id.uuidString): \(error.localizedDescription)")
        }
    }

    // MARK: - Cancel

    /// Cancels a pending reminder. Called when order is completed or deleted.
    static func cancelReminder(for order: Order) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [order.id.uuidString]
            )
    }

    // MARK: - Radar Digest

    /// Aggregates pending orders for the next 7 days and schedules a digest at 20:00.
    @MainActor
    static func updateEveningRadar(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Order>()
        guard let orders = try? modelContext.fetch(descriptor) else { return }
        
        let pendingOrders = orders.filter { $0.status == .baru || $0.status == .diproses }
        let calendar = Calendar.current
        let today = Date()
        
        let tomorrowOrders = pendingOrders.filter { calendar.isDateInTomorrow($0.deadline) }
        
        let day2Start = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: today)) ?? today
        let day7End = calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: today)) ?? today
        let next7DaysOrders = pendingOrders.filter { $0.deadline >= day2Start && $0.deadline < day7End }
        
        let countsTomorrow = tomorrowOrders.count
        let countsNext7 = next7DaysOrders.count
        
        guard countsTomorrow > 0 || countsNext7 > 0 else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["evening_radar"])
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Rangkuman Target Produksi"
        content.body = countsNext7 > 0 ? "Terdapat \(countsTomorrow) pesanan tenggat besok, dan \(countsNext7) pesanan pada minggu ini. Cek daftar untuk persiapan." : "Terdapat \(countsTomorrow) pesanan tenggat besok. Cek daftar untuk persiapan."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        // repeats: false limits to accurate snapshot.
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "evening_radar", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Successfully scheduled Evening Radar")
        } catch {
            logger.error("Failed to schedule Evening Radar: \(error.localizedDescription)")
        }
    }

    // MARK: - Badge

    /// Clears the app icon badge count. Call when app becomes active.
    static func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
