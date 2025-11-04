import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine


// FIX: Changed from a class to a struct. This makes JournalEntry a value type,
// which prevents complex state management issues caused by shared references.
// This is the core of the fix for the bug where updating one day's entry
// could visually affect another.
struct JournalEntry: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var year: Int
    var month: Int
    var day: Int
    var audioURL: String?
    var images: [String] = [] // This holds the final, remote URLs from Firebase.
    
    // This property holds temporary local images during the upload process.
    // It is not saved to Firebase.
    var localImages: [JournalImage] = []
    
    // Convert date components to Date when needed (timezone-independent)
    var date: Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // Initialize with date components from a Date (for creating new entries)
    init(id: String? = nil, date: Date, audioURL: String? = nil, images: [String] = [], localImages: [JournalImage] = []) {
        self.id = id
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
        self.audioURL = audioURL
        self.images = images
        self.localImages = localImages
    }

    // This computed property is now the single source of truth for what the UI should show.
    // It intelligently combines the final remote images with any temporary local ones.
    var displayImages: [JournalImage] {
        let remote = images.map { imagePath in
            // Check if this is a local file path (guest mode) or a remote URL
            if imagePath.hasPrefix("file://") || imagePath.hasPrefix("/") {
                // Local file path - load the image and create JournalImage with image property
                if let image = LocalStorageManager.shared.loadImage(from: imagePath) {
                    return JournalImage(id: imagePath, url: nil, image: image)
                } else {
                    return JournalImage(id: imagePath, url: imagePath)
                }
            } else {
                // Remote URL
                return JournalImage(id: imagePath, url: imagePath)
            }
        }
        
        return remote + localImages
    }
    
    // Check if the journal entry is completed (has both images and audio)
    var isCompleted: Bool {
        return !images.isEmpty && audioURL != nil
    }
    
    // Check if the journal entry has any content (images or audio)
    var hasContent: Bool {
        return !images.isEmpty || audioURL != nil
    }

    // Conformance for Hashable & Equatable
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: JournalEntry, rhs: JournalEntry) -> Bool { lhs.id == rhs.id }

    // We only encode/decode the properties that are stored in Firestore.
    enum CodingKeys: String, CodingKey {
        case id, year, month, day, images, audioURL, date
    }
    
    // Custom decoder to handle both old and new date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.audioURL = try container.decodeIfPresent(String.self, forKey: .audioURL)
        self.images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
        self.localImages = [] // Not stored in Firebase
        
        // Handle both old (date) and new (year/month/day) formats
        if let year = try container.decodeIfPresent(Int.self, forKey: .year),
           let month = try container.decodeIfPresent(Int.self, forKey: .month),
           let day = try container.decodeIfPresent(Int.self, forKey: .day) {
            // New format: year/month/day components
            self.year = year
            self.month = month
            self.day = day
        } else if let date = try container.decodeIfPresent(Date.self, forKey: .date) {
            // Old format: Date object - extract components using UTC to avoid timezone issues
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            self.year = components.year ?? 0
            self.month = components.month ?? 0
            self.day = components.day ?? 0
        } else {
            // Fallback to current date using UTC to avoid timezone issues
            let now = Date()
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let components = calendar.dateComponents([.year, .month, .day], from: now)
            self.year = components.year ?? 0
            self.month = components.month ?? 0
            self.day = components.day ?? 0
        }
    }
    
    // Custom encoder to always use new format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encode(images, forKey: .images)
        
        // Always encode in new format
        try container.encode(year, forKey: .year)
        try container.encode(month, forKey: .month)
        try container.encode(day, forKey: .day)
    }
}

// MARK: - Guest Mode Entry Model

/// A simplified model for guest mode entries that doesn't use Firebase dependencies
struct GuestJournalEntry: Identifiable, Codable, Hashable {
    var id: String
    var date: Date
    var audioURL: String?
    var images: [String] = []
    
    // This property holds temporary local images during the upload process.
    // It is not saved to local storage.
    var localImages: [JournalImage] = []
    
    init(id: String = UUID().uuidString, date: Date, audioURL: String? = nil, images: [String] = []) {
        self.id = id
        self.date = date
        self.audioURL = audioURL
        self.images = images
    }
    
    // This computed property is now the single source of truth for what the UI should show.
    // It intelligently combines the final local images with any temporary local ones.
    var displayImages: [JournalImage] {
        print("GuestJournalEntry: displayImages called, images.count: \(images.count), localImages.count: \(localImages.count)")
        
        let remote = images.map { imagePath in
            print("GuestJournalEntry: Processing image path: \(imagePath)")
            // Check if this is a local file path (guest mode) or a remote URL
            if imagePath.hasPrefix("file://") || imagePath.hasPrefix("/") {
                print("GuestJournalEntry: Detected local file path")
                // Local file path - load the image and create JournalImage with image property
                if let image = LocalStorageManager.shared.loadImage(from: imagePath) {
                    print("GuestJournalEntry: Successfully loaded local image")
                    return JournalImage(id: imagePath, url: nil, image: image)
                } else {
                    print("GuestJournalEntry: Failed to load local image from path: \(imagePath)")
                    return JournalImage(id: imagePath, url: imagePath)
                }
            } else {
                print("GuestJournalEntry: Detected remote URL")
                // Remote URL
                return JournalImage(id: imagePath, url: imagePath)
            }
        }
        
        let result = remote + localImages
        print("GuestJournalEntry: displayImages returning \(result.count) images")
        return result
    }
    
    // Check if the journal entry is completed (has both images and audio)
    var isCompleted: Bool {
        return !images.isEmpty && audioURL != nil
    }
    
    // Check if the journal entry has any content (images or audio)
    var hasContent: Bool {
        return !images.isEmpty || audioURL != nil
    }
    
    // Conformance for Hashable & Equatable
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GuestJournalEntry, rhs: GuestJournalEntry) -> Bool { lhs.id == rhs.id }
    
    // We only encode/decode the properties that are stored locally.
    enum CodingKeys: String, CodingKey {
        case id, date, images, audioURL
    }
}

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var monthsToDisplay: [Date] = []
    @Published var isLoadingMonths = false
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var imageCache = NSCache<NSString, UIImage>()
    private let calendar = Calendar.current
    var userID: String?
    
    // Notification manager for evening reminders
    private let notificationManager = NotificationManager.shared
    private let guestModeManager = GuestModeManager.shared
    private let localStorageManager = LocalStorageManager.shared
    
    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
    
    // Helper function to compare dates using components (timezone-independent)
    private func isSameDay(_ entry: JournalEntry, as date: Date) -> Bool {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let targetComponents = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return entry.year == targetComponents.year && 
               entry.month == targetComponents.month && 
               entry.day == targetComponents.day
    }
    
    /// Clears all data when switching users
    private func clearData() {
        entries.removeAll()
        monthsToDisplay.removeAll()
        userID = nil
        stopListening()
    }
    
    /// Forces reload of guest data when guest mode is re-enabled
    func reloadGuestData() {
        if guestModeManager.isGuestMode {
            clearData()
            loadGuestData()
        }
    }

    func fetchData(for userID: String) {
        if self.userID == userID, listenerRegistration != nil { 
            return 
        }
        
        // Clear existing data when switching users
        clearData()
        
        self.userID = userID
        stopListening()
        
        // Check if we're in guest mode
        if guestModeManager.isGuestMode {
            loadGuestData()
            return
        }
        
        let entriesRef = db.collection("users").document(userID).collection("entries")
        listenerRegistration = entriesRef.addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching entries: \(error)")
                    return
                }
                
                guard let querySnapshot = querySnapshot else { return }
                
                // Process initial data load (when listener first connects)
                if self.entries.isEmpty {
                    var initialEntries: [JournalEntry] = []
                    for document in querySnapshot.documents {
                        if var entryData = try? document.data(as: JournalEntry.self) {
                            // Set the document ID from Firestore
                            entryData.id = document.documentID
                            initialEntries.append(entryData)
                        }
                    }
                    self.entries = initialEntries
                    
                    // Schedule evening reminder after initial data load
                    self.scheduleEveningReminderIfNeeded()
                } else {
                    // Process only changes for subsequent updates
                    let changes = querySnapshot.documentChanges
                    print("CalendarViewModel: Processing \(changes.count) Firestore changes")
                    
                    for change in changes {
                        guard var changedEntryData = try? change.document.data(as: JournalEntry.self) else { continue }
                        // Set the document ID from Firestore
                        changedEntryData.id = change.document.documentID
                        
                        print("CalendarViewModel: Firestore change received - type: \(change.type), entryID: \(changedEntryData.id ?? "nil"), images: \(changedEntryData.images.count), date: \(changedEntryData.year)-\(changedEntryData.month)-\(changedEntryData.day)")

                        switch change.type {
                        case .added:
                            if !self.entries.contains(where: { $0.id == changedEntryData.id }) {
                                // Check if we have a local entry with the same date that might have localImages
                                if let dateIndex = self.entries.firstIndex(where: { 
                                    $0.year == changedEntryData.year && 
                                    $0.month == changedEntryData.month && 
                                    $0.day == changedEntryData.day 
                                }) {
                                    print("CalendarViewModel: .added event - found local entry with same date, preserving localImages")
                                    // Preserve existing localImages from the local entry
                                    var existingLocalImages = self.entries[dateIndex].localImages
                                    print("CalendarViewModel: existing localImages count: \(existingLocalImages.count)")
                                    // Remove any local images that are now in the remote images list
                                    existingLocalImages.removeAll { localImage in
                                        localImage.url != nil && changedEntryData.images.contains(localImage.url!)
                                    }
                                    print("CalendarViewModel: localImages after dedup: \(existingLocalImages.count)")
                                    changedEntryData.localImages = existingLocalImages
                                    // Replace the local entry with the one from Firestore (which has the proper ID)
                                    self.entries[dateIndex] = changedEntryData
                                    print("CalendarViewModel: replaced entry, final displayImages: \(self.entries[dateIndex].displayImages.count)")
                                } else {
                                    self.entries.append(changedEntryData)
                                }
                            }
                        case .modified:
                            // When an entry is modified from Firestore, we find the matching
                            // local entry and preserve any temporary localImages that haven't
                            // been uploaded yet. This prevents images from disappearing during
                            // the upload process.
                            
                            if let index = self.entries.firstIndex(where: { $0.id == changedEntryData.id }) {
                                print("CalendarViewModel: .modified event - found entry by ID, preserving localImages")
                                // Preserve existing localImages and merge them with the new data
                                var existingLocalImages = self.entries[index].localImages
                                print("CalendarViewModel: existing localImages count: \(existingLocalImages.count)")
                                // Remove any local images that are now in the remote images list
                                // to prevent duplicates (this handles the case where upload completed)
                                existingLocalImages.removeAll { localImage in
                                    localImage.url != nil && changedEntryData.images.contains(localImage.url!)
                                }
                                print("CalendarViewModel: localImages after dedup: \(existingLocalImages.count)")
                                changedEntryData.localImages = existingLocalImages
                                self.entries[index] = changedEntryData
                                print("CalendarViewModel: updated entry, final displayImages: \(self.entries[index].displayImages.count)")
                            } else {
                                // If we can't find the entry by ID, try to find it by date and update it
                                if let dateIndex = self.entries.firstIndex(where: { 
                                    $0.year == changedEntryData.year && 
                                    $0.month == changedEntryData.month && 
                                    $0.day == changedEntryData.day 
                                }) {
                                    print("CalendarViewModel: .modified event - found entry by date, preserving localImages")
                                    // Preserve existing localImages and merge them with the new data
                                    var existingLocalImages = self.entries[dateIndex].localImages
                                    print("CalendarViewModel: existing localImages count: \(existingLocalImages.count)")
                                    // Remove any local images that are now in the remote images list
                                    // to prevent duplicates (this handles the case where upload completed)
                                    existingLocalImages.removeAll { localImage in
                                        localImage.url != nil && changedEntryData.images.contains(localImage.url!)
                                    }
                                    print("CalendarViewModel: localImages after dedup: \(existingLocalImages.count)")
                                    changedEntryData.localImages = existingLocalImages
                                    self.entries[dateIndex] = changedEntryData
                                    print("CalendarViewModel: updated entry, final displayImages: \(self.entries[dateIndex].displayImages.count)")
                                } else {
                                    // If we still can't find it, add it
                                    print("CalendarViewModel: .modified event - no matching entry found, appending")
                                    self.entries.append(changedEntryData)
                                }
                            }
                        case .removed:
                            self.entries.removeAll(where: { $0.id == changedEntryData.id })
                        }
                    }
                    
                    // Schedule evening reminder after data changes
                    self.scheduleEveningReminderIfNeeded()
                    
                    // Clear app badge if today's entry is completed
                    self.clearBadgeIfEntryCompleted()
                }
            }
        }
    
    // --- Start of NEW/MODIFIED FUNCTIONS for Infinite Scroll ---

    func loadInitialMonths() {
        // Load only the current year's 12 months (January through December)
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        
        guard let january = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) else { return }
        
        var months: [Date] = []
        var currentDate = startOfMonth(for: january)
        
        for _ in 0..<12 {
            months.append(currentDate)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        self.monthsToDisplay = months
    }
    
    func loadMorePastMonths() {
        guard !isLoadingMonths else { return }
        isLoadingMonths = true

        guard let firstMonth = monthsToDisplay.first,
              let sixMonthsBefore = calendar.date(byAdding: .month, value: -6, to: firstMonth) else {
            isLoadingMonths = false
            return
        }
        
        var pastMonths: [Date] = []
        var currentDate = startOfMonth(for: sixMonthsBefore)
        
        for _ in 0..<6 {
            pastMonths.append(currentDate)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        
        self.monthsToDisplay.insert(contentsOf: pastMonths, at: 0)
        
        // Asynchronously reset the flag after a short delay to allow the UI to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingMonths = false
        }
    }
    
    func loadMoreFutureMonths() {
        guard !isLoadingMonths else { return }
        isLoadingMonths = true

        guard let lastMonth = monthsToDisplay.last,
              let oneMonthAfter = calendar.date(byAdding: .month, value: 1, to: lastMonth) else {
            isLoadingMonths = false
            return
        }
        
        var futureMonths: [Date] = []
        var currentDate = startOfMonth(for: oneMonthAfter)
        
        for _ in 0..<6 {
            futureMonths.append(currentDate)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        
        self.monthsToDisplay.append(contentsOf: futureMonths)
        
        // Asynchronously reset the flag after a short delay to allow the UI to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoadingMonths = false
        }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
    }

    private func generateMonthRange() {
        guard let firstEntryDate = entries.min(by: { $0.date < $1.date })?.date else {
            monthsToDisplay = [startOfMonth(for: Date())]
            return
        }
        
        let endDate = Date()
        var months: [Date] = []
        var currentDate = startOfMonth(for: firstEntryDate)

        while currentDate <= endDate {
            months.append(currentDate)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        
        if !months.contains(where: { calendar.isDate($0, inSameDayAs: startOfMonth(for: endDate)) }) {
             months.append(startOfMonth(for: endDate))
        }

        self.monthsToDisplay = months.sorted(by: <)
    }
    
    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)!
    }

    func entryFor(date: Date) -> JournalEntry? {
        // Use UTC calendar for consistent date comparison (same as isSameDay function)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let targetComponents = utcCalendar.dateComponents([.year, .month, .day], from: date)
        
        // Check if we're in guest mode
        if guestModeManager.isGuestMode {
            // First check the entries array (which should have the most recent data)
            if let entry = entries.first(where: { 
                $0.year == targetComponents.year && 
                $0.month == targetComponents.month && 
                $0.day == targetComponents.day 
            }) {
                return entry
            }
            
            // Fall back to local storage
            return localStorageManager.getJournalEntry(for: date)
        }
        
        return entries.first { entry in
            entry.year == targetComponents.year && 
            entry.month == targetComponents.month && 
            entry.day == targetComponents.day
        }
    }
    
    /// Checks if there are entries from previous years for a given date (same month/day, different year)
    func hasEntriesFromPreviousYears(for date: Date) -> Bool {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let targetComponents = utcCalendar.dateComponents([.year, .month, .day], from: date)
        let currentYear = targetComponents.year ?? 0
        let targetMonth = targetComponents.month ?? 0
        let targetDay = targetComponents.day ?? 0
        
        // Check if there are any entries with the same month/day but different (earlier) year
        return entries.contains { entry in
            entry.month == targetMonth &&
            entry.day == targetDay &&
            entry.year < currentYear
        }
    }
    
    /// Gets all entries for a specific month/day combination across all years, sorted by year descending
    func entriesForDayAcrossYears(month: Int, day: Int) -> [JournalEntry] {
        let matchingEntries = entries.filter { entry in
            entry.month == month && entry.day == day
        }
        return matchingEntries.sorted { $0.year > $1.year }
    }
    
    /// Gets the count of entries for a specific month/day combination across all years
    func entryCountForDayAcrossYears(month: Int, day: Int) -> Int {
        return entries.filter { entry in
            entry.month == month && entry.day == day
        }.count
    }
    
    // MARK: - Guest Mode Support
    
    private func loadGuestData() {
        // Only load if entries array is empty to avoid overwriting in-memory changes
        if entries.isEmpty {
            // Load local journal entries
            let localEntries = localStorageManager.getAllJournalEntries()
            self.entries = localEntries
        }
        
        // Load initial months like in signed-in mode
        if monthsToDisplay.isEmpty {
            loadInitialMonths()
        }
        
        // Schedule evening reminder if needed
        scheduleEveningReminderIfNeeded()
    }
    
    private func addImageToGuestMode(to date: Date, imageData: Data) {
        // Save image locally
        guard let image = UIImage(data: imageData),
              let localPath = localStorageManager.saveImageLocally(image, for: date) else {
            return
        }
        
        // Get or create entry for this date - check entries array first, then local storage
        var entry: JournalEntry
        if let existingEntry = entries.first(where: { isSameDay($0, as: date) }) {
            entry = existingEntry
        } else {
            entry = localStorageManager.getJournalEntry(for: date) ?? JournalEntry(id: nil, date: date)
        }
        
        // Add image path to entry
        entry.images.append(localPath)
        
        // Save entry locally
        localStorageManager.saveJournalEntry(entry)
        
        // Update UI
        if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            entries[entryIndex] = entry
        } else {
            entries.append(entry)
        }
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Schedule evening reminder if needed
        scheduleEveningReminderIfNeeded()
    }
    
    private func setAudioToGuestMode(for date: Date, audioURL: URL) {
        // Get or create entry for this date - check entries array first, then local storage
        var entry: JournalEntry
        if let existingEntry = entries.first(where: { isSameDay($0, as: date) }) {
            entry = existingEntry
        } else {
            entry = localStorageManager.getJournalEntry(for: date) ?? JournalEntry(id: nil, date: date)
        }
        
        // Set audio URL to entry
        entry.audioURL = audioURL.absoluteString
        
        // Save entry locally
        localStorageManager.saveJournalEntry(entry)
        
        // Update UI
        if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            entries[entryIndex] = entry
        } else {
            entries.append(entry)
        }
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        // Schedule evening reminder if needed
        scheduleEveningReminderIfNeeded()
    }
    
    private func deleteAudioFromGuestMode(for date: Date) {
        // Get entry for this date - check entries array first, then local storage
        var entry: JournalEntry
        if let existingEntry = entries.first(where: { isSameDay($0, as: date) }) {
            entry = existingEntry
        } else {
            guard let localEntry = localStorageManager.getJournalEntry(for: date) else { return }
            entry = localEntry
        }
        
        // Remove audio URL from entry
        entry.audioURL = nil
        
        // Always save the updated entry (even if empty) to preserve the date in calendar
        localStorageManager.saveJournalEntry(entry)
        
        // Update UI - keep entry in array even if empty so calendar can show it
        if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            entries[entryIndex] = entry
        } else {
            // Add entry to UI even if empty, so calendar can show the date
            entries.append(entry)
        }
        
        // Schedule evening reminder if needed
        scheduleEveningReminderIfNeeded()
    }
    
    private func deleteImageFromGuestMode(from date: Date, journalImage: JournalImage) {
        // Get entry for this date - check entries array first, then local storage
        var entry: JournalEntry
        if let existingEntry = entries.first(where: { isSameDay($0, as: date) }) {
            entry = existingEntry
        } else {
            guard let localEntry = localStorageManager.getJournalEntry(for: date) else { return }
            entry = localEntry
        }
        
        // Remove image from entry
        entry.images.removeAll { $0 == journalImage.url }
        
        // Delete the local image file
        if let imageURL = journalImage.url {
            localStorageManager.deleteImage(at: imageURL)
        }
        
        // Always save the updated entry (even if empty) to preserve the date in calendar
        localStorageManager.saveJournalEntry(entry)
        
        // Update UI - keep entry in array even if empty so calendar can show it
        if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            entries[entryIndex] = entry
        } else {
            // Add entry to UI even if empty, so calendar can show the date
            entries.append(entry)
        }
        
        // Schedule evening reminder if needed
        scheduleEveningReminderIfNeeded()
    }
    
    private func entryID(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = AppConstants.Firebase.dateFormat
        formatter.timeZone = TimeZone(identifier: "UTC")!
        return formatter.string(from: date)
    }
    
    // FIX: Modified to work with the new struct-based model.
    func addImage(to date: Date, imageData: Data, for userID: String) {
        // Check if we're in guest mode
        if guestModeManager.isGuestMode {
            addImageToGuestMode(to: date, imageData: imageData)
            return
        }
        
        let dateID = entryID(for: date)
        
        // Create a temporary local image representation.
        let tempImage = JournalImage(id: UUID().uuidString, image: UIImage(data: imageData))
        
        // Optimistically update the UI by adding the temp image to the correct entry's `localImages`.
        if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            print("CalendarViewModel: addImage - found existing entry, adding temp image with ID: \(tempImage.id)")
            entries[entryIndex].localImages.append(tempImage)
            print("CalendarViewModel: addImage - entry now has \(entries[entryIndex].localImages.count) localImages, displayImages: \(entries[entryIndex].displayImages.count)")
        } else {
            // If no entry exists for the date, create a new one.
            print("CalendarViewModel: addImage - creating new entry with temp image ID: \(tempImage.id)")
            let newEntry = JournalEntry(id: dateID, date: date, localImages: [tempImage])
            entries.append(newEntry)
            print("CalendarViewModel: addImage - new entry has \(newEntry.localImages.count) localImages, displayImages: \(newEntry.displayImages.count)")
        }
        
        Task {
            // Perform the upload in the background.
            guard let imageToUpload = tempImage.image,
                  let resizedImage = imageToUpload.resized(to: AppConstants.Dimensions.maxImageDimension),
                  let imageData = resizedImage.jpegData(compressionQuality: AppConstants.Dimensions.imageCompressionQuality) else { return }
            
            let imageUUID = UUID().uuidString
            let storageRef = Storage.storage().reference().child("\(userID)/\(imageUUID).jpg")
            
            do {
                _ = try await storageRef.putDataAsync(imageData)
                let downloadURL = try await storageRef.downloadURL()
                let urlString = downloadURL.absoluteString
                
                // Update Firestore. The snapshot listener will then receive this change.
                let entryRef = db.collection("users").document(userID).collection("entries").document(dateID)
                var utcCalendar = Calendar(identifier: .gregorian)
                utcCalendar.timeZone = TimeZone(identifier: "UTC")!
                let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
                try await entryRef.setData([
                    "images": FieldValue.arrayUnion([urlString]), 
                    "year": components.year ?? 0,
                    "month": components.month ?? 0,
                    "day": components.day ?? 0
                ], merge: true)
                
                // Once the remote operation is complete, remove the temporary local image.
                // The UI will now be showing the permanent remote image via the listener update.
                print("CalendarViewModel: addImage - upload complete, removing temp image with ID: \(tempImage.id)")
                if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
                    entries[entryIndex].localImages.removeAll { $0.id == tempImage.id }
                    print("CalendarViewModel: addImage - temp image removed, entry now has \(entries[entryIndex].localImages.count) localImages, displayImages: \(entries[entryIndex].displayImages.count)")
                }
            } catch {
                print("Error uploading image: \(error)")
                // Optional: handle error, e.g., remove the temp image on failure.
            }
        }
    }

// FIX: Modified to work with structs.
func deleteImage(from date: Date, journalImage: JournalImage, for userID: String) async {
        // Check if we're in guest mode
        if guestModeManager.isGuestMode {
            deleteImageFromGuestMode(from: date, journalImage: journalImage)
            return
        }
        
        let dateID = entryID(for: date)
        
        // Optimistic UI update: remove the image immediately from the local model.
        // First try to find by ID, then fall back to date-based lookup
        var entryIndex: Int?
        if let idIndex = entries.firstIndex(where: { $0.id == dateID }) {
            entryIndex = idIndex
        } else if let dateIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            entryIndex = dateIndex
        }
        
        if let entryIndex = entryIndex {
            var modifiedEntry = entries[entryIndex]
            
            // Remove from either remote or local images list.
            modifiedEntry.images.removeAll { $0 == journalImage.url }
            modifiedEntry.localImages.removeAll { $0.id == journalImage.id }
            
            // Always keep the entry in the array (even if empty) so calendar can show it
            entries[entryIndex] = modifiedEntry
        }
        
        // Backend deletion (only if it's a remote image with a URL).
        guard let imageURL = journalImage.url else {
            return
        }

        let entryRef = db.collection("users").document(userID).collection("entries").document(dateID)
        let storageRef = Storage.storage().reference(forURL: imageURL)

        do {
            // Try to delete from Storage, but don't fail if the file doesn't exist
            do {
                try await storageRef.delete()
            } catch {
                // Check if it's a 404 error (file not found)
                let storageError = error as NSError
                if storageError.domain == "com.google.HTTPStatus" && storageError.code == 404 {
                    // Image not found in Storage, but continuing with database cleanup
                } else {
                    // Continue with database cleanup even if Storage deletion fails
                }
            }
            
            // Always update the database to remove the reference, regardless of Storage deletion result
            try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let entryDocument: DocumentSnapshot
                do {
                    try entryDocument = transaction.getDocument(entryRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard var images = entryDocument.data()?["images"] as? [String] else { return nil }
                images.removeAll { $0 == imageURL }
                
                // Always update the images array, even if empty, to preserve the entry
                transaction.updateData(["images": images], forDocument: entryRef)
                return nil
            })
            
        } catch {
            // Note: In a production app, you might want to revert the optimistic update on failure.
        }
    }

    func setAudio(for date: Date, audioURL: URL, for userID: String) async {
        // Check if we're in guest mode
        if guestModeManager.isGuestMode {
            setAudioToGuestMode(for: date, audioURL: audioURL)
            return
        }
        
        let dateID = entryID(for: date)
        let storageRef = Storage.storage().reference().child("\(userID)/\(dateID).m4a")
        let entryRef = db.collection("users").document(userID).collection("entries").document(dateID)
        
        do {
            _ = try await storageRef.putFileAsync(from: audioURL)
            let downloadURL = try await storageRef.downloadURL()
            let urlString = downloadURL.absoluteString
            
            // Update Firestore in the background
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!
            let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
            try await entryRef.setData([
                "audioURL": urlString, 
                "year": components.year ?? 0,
                "month": components.month ?? 0,
                "day": components.day ?? 0
            ], merge: true)
            
            // Update local model
            if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
                entries[entryIndex].audioURL = urlString
            } else {
                let newEntry = JournalEntry(id: dateID, date: date, audioURL: urlString)
                entries.append(newEntry)
            }
            
        } catch {
            print("Error uploading audio or updating Firestore: \(error)")
        }
    }
    
    func appendAudio(for date: Date, audioURL: URL, for userID: String) async {
        // This is the same as setAudio since we handle the combining in AudioRecorder
        await setAudio(for: date, audioURL: audioURL, for: userID)
    }

    func deleteAudio(for date: Date, userID: String) async {
        // Check if we're in guest mode
        if guestModeManager.isGuestMode {
            deleteAudioFromGuestMode(for: date)
            return
        }
        
        // Optimistically update the local UI first
        if let entryIndex = entries.firstIndex(where: { isSameDay($0, as: date) }) {
            var modifiedEntry = entries[entryIndex]
            modifiedEntry.audioURL = nil
            
            // Always keep the entry in the array (even if empty) so calendar can show it
            entries[entryIndex] = modifiedEntry
        }
        
        // Then, perform the backend deletion
        let dateID = entryID(for: date)
        let entryRef = db.collection("users").document(userID).collection("entries").document(dateID)
        let storageRef = Storage.storage().reference().child("\(userID)/\(dateID).m4a")
        
        do {
            try await storageRef.delete()
            try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let entryDocument: DocumentSnapshot
                do {
                    try entryDocument = transaction.getDocument(entryRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                // Always update the audioURL field, even if it makes the entry empty
                transaction.updateData(["audioURL": FieldValue.delete()], forDocument: entryRef)
                return nil
            })
        } catch {
             print("Error deleting audio or running transaction: \(error)")
        }
    }
    
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        loadImage(from: urlString, retryCount: 0, completion: completion)
    }
    
    private func loadImage(from urlString: String, retryCount: Int, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = NSString(string: urlString)
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
            }
            
            // Try to create UIImage
            guard let image = UIImage(data: data) else {
                // Retry logic for network-related failures
                if retryCount < 2 && (data.count == 0 || data.count < 100) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.loadImage(from: urlString, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                // If this is a Firebase Storage URL and we've exhausted retries, try direct Firebase download
                if retryCount == 2 && urlString.contains("firebasestorage.googleapis.com") {
                    self.loadImageFromFirebaseStorage(urlString: urlString, completion: completion)
                    return
                }
                
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.imageCache.setObject(image, forKey: cacheKey)
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
    
    private func loadImageFromFirebaseStorage(urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Extract the storage path from the Firebase Storage URL
        // URL format: https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Ffile?alt=media&token=...
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        // Check if this is a valid Firebase Storage URL
        guard components.queryItems?.contains(where: { $0.name == "alt" && $0.value == "media" }) == true else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        // Extract the file path from the URL
        let pathComponents = url.pathComponents
        guard pathComponents.count > 2 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        
        // Reconstruct the storage path (skip the first two components: "/v0/b/bucket/o/")
        let storagePath = pathComponents.dropFirst(4).joined(separator: "/")
        
        let storageRef = Storage.storage().reference().child(storagePath)
        
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Cache the image using the original URL as the key
            let cacheKey = NSString(string: urlString)
            self.imageCache.setObject(image, forKey: cacheKey)
            
            DispatchQueue.main.async { completion(image) }
        }
    }
    
    // MARK: - Notification Management
    
    /// Schedules evening reminder if user doesn't have a completed entry for today
    private func scheduleEveningReminderIfNeeded() {
        guard let userID = userID else { return }
        
        let today = Date()
        let entry = entryFor(date: today)
        let hasCompletedEntryForToday = entry?.isCompleted ?? false
        
        notificationManager.onJournalEntryUpdated(for: userID, hasEntryForToday: hasCompletedEntryForToday)
    }
    
    /// Clears app badge if today's entry is completed
    private func clearBadgeIfEntryCompleted() {
        let today = Date()
        let entry = entryFor(date: today)
        let isCompleted = entry?.isCompleted ?? false
        
        if isCompleted {
            notificationManager.clearAppBadge()
        }
    }
}

extension UIImage {
    func resized(to maxDimension: CGFloat) -> UIImage? {
        let size = self.size
        let scale: CGFloat
        if size.width > size.height {
            scale = maxDimension / size.width
        } else {
            scale = maxDimension / size.height
        }
        
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
