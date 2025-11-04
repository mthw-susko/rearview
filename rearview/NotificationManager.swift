//
//  NotificationManager.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import Foundation
import UserNotifications
import SwiftUI

/// Manages local notifications for journal reminders
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var eveningReminderTime = DateComponents(hour: 20, minute: 0) // 8:00 PM default
    
    private let userDefaultsManager = UserDefaultsManager.shared
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let eveningReminderIdentifier = "evening_journal_reminder"
    
    private override init() {
        super.init()
        loadEveningReminderTime()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    /// Requests notification permissions from the user
    func requestAuthorization() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        } catch {
            print("Error requesting notification permission: \(error)")
        }
    }
    
    /// Checks the current authorization status
    private func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Evening Reminder Management
    
    /// Schedules the evening journal reminder for today if no entry exists
    func scheduleEveningReminderIfNeeded(for userID: String, hasEntryForToday: Bool) {
        // Only schedule if user is authorized and doesn't have an entry for today
        guard isAuthorized, !hasEntryForToday else {
            return
        }
        
        // Cancel any existing evening reminder
        cancelEveningReminder()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to journal! 📝"
        content.body = "Don't forget to add photos or audio to today's journal entry"
        content.sound = .default
        content.badge = 1
        
        // Create trigger for this evening
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: eveningReminderTime,
            repeats: false
        )
        
        // Create request
        let request = UNNotificationRequest(
            identifier: eveningReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling evening reminder: \(error)")
            }
        }
    }
    
    /// Cancels the evening reminder notification
    func cancelEveningReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [eveningReminderIdentifier])
        print("Evening reminder cancelled")
    }
    
    /// Updates the evening reminder time and reschedules if needed
    func updateEveningReminderTime(_ time: DateComponents) {
        eveningReminderTime = time
        saveEveningReminderTime()
        // Note: In a real app, you might want to reschedule existing notifications
        // For now, we'll just update the time for future scheduling
    }
    
    // MARK: - Entry-based Notifications
    
    /// Called when a journal entry is created or updated
    func onJournalEntryUpdated(for userID: String, hasEntryForToday: Bool) {
        if hasEntryForToday {
            // User has created an entry, cancel the evening reminder
            cancelEveningReminder()
        } else {
            // User doesn't have an entry, schedule evening reminder
            scheduleEveningReminderIfNeeded(for: userID, hasEntryForToday: false)
        }
    }
    
    /// Called when the app becomes active to check if reminder is still needed
    func checkAndRescheduleReminder(for userID: String, hasEntryForToday: Bool) {
        // Cancel any existing reminder first
        cancelEveningReminder()
        
        // If user doesn't have an entry and it's still early enough in the day, reschedule
        if !hasEntryForToday {
            let calendar = Calendar.current
            let now = Date()
            let currentHour = calendar.component(.hour, from: now)
            let reminderHour = eveningReminderTime.hour ?? 20
            
            // Only reschedule if we haven't passed the reminder time yet
            if currentHour < reminderHour {
                scheduleEveningReminderIfNeeded(for: userID, hasEntryForToday: false)
            }
        }
    }
    
    // MARK: - Debug Methods
    
    /// Gets all pending notifications (for debugging)
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    /// Clears all notifications (for debugging)
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        clearAppBadge()
        print("All notifications cleared")
    }
    
    /// Clears the app badge
    func clearAppBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    // MARK: - Persistence
    
    /// Saves the evening reminder time to UserDefaults
    private func saveEveningReminderTime() {
        userDefaultsManager.saveEveningReminderTime(
            hour: eveningReminderTime.hour ?? 20,
            minute: eveningReminderTime.minute ?? 0
        )
    }
    
    /// Loads the evening reminder time from UserDefaults
    private func loadEveningReminderTime() {
        let savedTime = userDefaultsManager.loadEveningReminderTime()
        eveningReminderTime = DateComponents(hour: savedTime.hour, minute: savedTime.minute)
    }
    
}

// MARK: - Notification Delegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Called when a notification is delivered while the app is in the foreground
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Called when the user taps on a notification
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap - could navigate to today's journal entry
        print("User tapped on notification: \(response.notification.request.identifier)")
        completionHandler()
    }
}
