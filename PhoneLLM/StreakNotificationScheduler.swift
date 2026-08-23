import Foundation
import UserNotifications

/// Schedules the evening "your streak is at risk" reminder. Deliberately
/// scoped to the streak/XP game mechanic — it never references sleep, steps,
/// or Screen Time directly, so it can't read as a health judgment.
enum StreakNotificationScheduler {
    private static let identifier = "streak-reminder"
    private static let reminderHour = 20

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func scheduleReminderIfNeeded(streak: Int, allQuestsDone: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard !allQuestsDone else { return }

        var components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: .now)
        components.hour = reminderHour
        components.minute = 0

        guard
            let fireDate = Calendar.autoupdatingCurrent.date(from: components),
            fireDate > .now
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your streak is at risk 🔥"
        content.body = streak > 0
            ? "Finish today's quest to keep your \(streak)-day streak alive."
            : "Finish today's quest to start a new streak."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.autoupdatingCurrent.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            ),
            repeats: false
        )
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
