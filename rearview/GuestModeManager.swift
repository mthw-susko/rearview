//
//  GuestModeManager.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

/// Manages guest mode functionality and local storage
class GuestModeManager: ObservableObject {
    static let shared = GuestModeManager()
    
    @Published var isGuestMode = false
    @Published var guestProfileImage: UIImage?
    
    private let userDefaults = UserDefaults.standard
    private let guestModeKey = "isGuestMode"
    private let guestProfileImageKey = "guestProfileImage"
    
    private init() {
        loadGuestModeState()
    }
    
    // MARK: - Guest Mode Management
    
    /// Enables guest mode
    func enableGuestMode() {
        isGuestMode = true
        userDefaults.set(true, forKey: guestModeKey)
    }
    
    /// Disables guest mode (when user signs up or signs out)
    func disableGuestMode() {
        isGuestMode = false
        userDefaults.set(false, forKey: guestModeKey)
        // Don't clear the profile image - keep it for when user returns to guest mode
        // guestProfileImage = nil
        // userDefaults.removeObject(forKey: guestProfileImageKey)
    }
    
    /// Temporarily disables guest mode for sign-in (preserves data)
    func disableGuestModeForSignIn() {
        isGuestMode = false
        userDefaults.set(false, forKey: guestModeKey)
    }
    
    /// Completely clears guest mode data (when user actually signs up)
    func clearGuestModeData() {
        isGuestMode = false
        userDefaults.set(false, forKey: guestModeKey)
        guestProfileImage = nil
        userDefaults.removeObject(forKey: guestProfileImageKey)
    }
    
    /// Loads guest mode state from UserDefaults
    private func loadGuestModeState() {
        isGuestMode = userDefaults.bool(forKey: guestModeKey)
        loadGuestProfileImage()
    }
    
    // MARK: - Profile Image Management
    
    /// Saves guest profile image locally
    func saveGuestProfileImage(_ image: UIImage) {
        guestProfileImage = image
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            userDefaults.set(imageData, forKey: guestProfileImageKey)
        }
    }
    
    /// Loads guest profile image from local storage
    private func loadGuestProfileImage() {
        if let imageData = userDefaults.data(forKey: guestProfileImageKey),
           let image = UIImage(data: imageData) {
            guestProfileImage = image
        }
    }
    
    /// Clears guest profile image
    func clearGuestProfileImage() {
        guestProfileImage = nil
        userDefaults.removeObject(forKey: guestProfileImageKey)
    }
    
    // MARK: - Data Migration
    
    /// Migrates guest data to authenticated user
    func migrateGuestDataToUser(userID: String, completion: @escaping (Bool) -> Void) {
        // This will be called when user signs up
        // We'll implement the migration logic here
        Task {
            do {
                // Migrate journal entries
                try await migrateJournalEntries(to: userID)
                
                // Migrate profile image
                if let profileImage = guestProfileImage {
                    try await migrateProfileImage(profileImage, to: userID)
                }
                
                // Clear guest data
                await MainActor.run {
                    self.disableGuestMode()
                    completion(true)
                }
            } catch {
                await MainActor.run {
                    completion(false)
                }
            }
        }
    }
    
    private func migrateJournalEntries(to userID: String) async throws {
        // Get all local journal entries
        let localEntries = LocalStorageManager.shared.getAllJournalEntries()
        
        // Upload each entry to Firebase
        for entry in localEntries {
            try await uploadJournalEntryToFirebase(entry, for: userID)
        }
        
        // Clear local entries after successful migration
        LocalStorageManager.shared.clearAllJournalEntries()
    }
    
    private func migrateProfileImage(_ image: UIImage, to userID: String) async throws {
        // Upload profile image to Firebase
        try await uploadProfileImageToFirebase(image, for: userID)
    }
    
    // MARK: - Firebase Upload Methods
    
    private func uploadJournalEntryToFirebase(_ entry: JournalEntry, for userID: String) async throws {
        let db = Firestore.firestore()
        let entryRef = db.collection("users").document(userID).collection("entries").document(entry.id ?? UUID().uuidString)
        
        try await entryRef.setData([
            "date": entry.date,
            "images": entry.images,
            "audioURL": entry.audioURL ?? ""
        ])
    }
    
    private func uploadProfileImageToFirebase(_ image: UIImage, for userID: String) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageConversionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference().child("profile_images/\(userID).jpg")
        
        let _ = try await storageRef.putDataAsync(imageData)
        let downloadURL = try await storageRef.downloadURL()
        
        // Update user document with profile image URL
        let db = Firestore.firestore()
        try await db.collection("users").document(userID).setData([
            "profileImageURL": downloadURL.absoluteString
        ], merge: true)
    }
}

// MARK: - Local Storage Manager

/// Manages local storage for guest users
class LocalStorageManager {
    static let shared = LocalStorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let journalEntriesKey = "localJournalEntries"
    
    private init() {}
    
    // MARK: - Journal Entries
    
    /// Saves a journal entry locally
    func saveJournalEntry(_ entry: JournalEntry) {
        // Convert JournalEntry to GuestJournalEntry for local storage
        let guestEntry = GuestJournalEntry(
            id: entry.id ?? UUID().uuidString,
            date: entry.date,
            audioURL: entry.audioURL,
            images: entry.images
        )
        saveGuestJournalEntry(guestEntry)
    }
    
    /// Saves a guest journal entry locally
    func saveGuestJournalEntry(_ entry: GuestJournalEntry) {
        var entries = getAllGuestJournalEntries()
        
        // Remove existing entry for the same date
        entries.removeAll { $0.date == entry.date }
        
        // Add new entry
        entries.append(entry)
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: journalEntriesKey)
        }
    }
    
    /// Gets all local journal entries
    func getAllJournalEntries() -> [JournalEntry] {
        // Convert GuestJournalEntry to JournalEntry for compatibility
        let guestEntries = getAllGuestJournalEntries()
        return guestEntries.map { guestEntry in
            var journalEntry = JournalEntry(date: guestEntry.date, audioURL: guestEntry.audioURL, images: guestEntry.images)
            journalEntry.id = guestEntry.id
            return journalEntry
        }
    }
    
    /// Gets all local guest journal entries
    func getAllGuestJournalEntries() -> [GuestJournalEntry] {
        guard let data = userDefaults.data(forKey: journalEntriesKey),
              let entries = try? JSONDecoder().decode([GuestJournalEntry].self, from: data) else {
            return []
        }
        return entries
    }
    
    /// Gets journal entry for specific date
    func getJournalEntry(for date: Date) -> JournalEntry? {
        let guestEntries = getAllGuestJournalEntries()
        
        // Use UTC calendar for consistent date comparison
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let targetComponents = utcCalendar.dateComponents([.year, .month, .day], from: date)
        
        let foundGuestEntry = guestEntries.first { guestEntry in
            let entryComponents = utcCalendar.dateComponents([.year, .month, .day], from: guestEntry.date)
            return entryComponents.year == targetComponents.year &&
                   entryComponents.month == targetComponents.month &&
                   entryComponents.day == targetComponents.day
        }
        
        if let guestEntry = foundGuestEntry {
            var journalEntry = JournalEntry(date: guestEntry.date, audioURL: guestEntry.audioURL, images: guestEntry.images)
            journalEntry.id = guestEntry.id
            return journalEntry
        }
        
        return nil
    }
    
    /// Deletes journal entry for specific date
    func deleteJournalEntry(for date: Date) {
        var entries = getAllGuestJournalEntries()
        
        // Use UTC calendar for consistent date comparison
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let targetComponents = utcCalendar.dateComponents([.year, .month, .day], from: date)
        
        entries.removeAll { guestEntry in
            let entryComponents = utcCalendar.dateComponents([.year, .month, .day], from: guestEntry.date)
            return entryComponents.year == targetComponents.year &&
                   entryComponents.month == targetComponents.month &&
                   entryComponents.day == targetComponents.day
        }
        
        if let data = try? JSONEncoder().encode(entries) {
            userDefaults.set(data, forKey: journalEntriesKey)
        }
    }
    
    /// Clears all journal entries (used after migration)
    func clearAllJournalEntries() {
        userDefaults.removeObject(forKey: journalEntriesKey)
    }
    
    // MARK: - Image Storage
    
    /// Saves image locally and returns local file path
    func saveImageLocally(_ image: UIImage, for entryDate: Date) -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsPath.appendingPathComponent("LocalImages")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        
        // Generate unique filename
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let filename = "\(formatter.string(from: entryDate))-\(UUID().uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        // Save image
        if let imageData = image.jpegData(compressionQuality: 0.9) {
            try? imageData.write(to: fileURL)
            return fileURL.path
        }
        
        return nil
    }
    
    /// Loads image from local file path
    func loadImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }
    
    /// Deletes local image file
    func deleteImage(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
