//
//  UserDefaultsManager.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import Foundation

/// Manages UserDefaults for app settings and first launch tracking
class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    private let eveningReminderTimeKey = "eveningReminderTime"
    
    private init() {}
    
    // MARK: - First Launch
    
    /// Checks if this is the first time the app has been launched
    var hasLaunchedBefore: Bool {
        return userDefaults.bool(forKey: hasLaunchedBeforeKey)
    }
    
    /// Marks that the app has been launched before
    func markAsLaunched() {
        userDefaults.set(true, forKey: hasLaunchedBeforeKey)
    }
    
    // MARK: - Evening Reminder Time
    
    /// Saves the evening reminder time
    func saveEveningReminderTime(hour: Int, minute: Int) {
        let timeData: [String: Any] = [
            "hour": hour,
            "minute": minute
        ]
        userDefaults.set(timeData, forKey: eveningReminderTimeKey)
    }
    
    /// Loads the evening reminder time
    func loadEveningReminderTime() -> (hour: Int, minute: Int) {
        if let timeData = userDefaults.dictionary(forKey: eveningReminderTimeKey),
           let hour = timeData["hour"] as? Int,
           let minute = timeData["minute"] as? Int {
            return (hour: hour, minute: minute)
        }
        return (hour: 20, minute: 0) // Default to 8:00 PM
    }
}
