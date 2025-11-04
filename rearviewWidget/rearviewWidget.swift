//
//  rearviewWidget.swift
//  rearviewWidget
//
//  Created by Matthew Susko on 2025-09-29.
//

/*
 * REARVIEW WIDGET IMPLEMENTATION
 * ==============================
 * 
 * This file contains the complete implementation of the rearview calendar widget.
 * The widget displays the current month with daily journal entries and their thumbnails,
 * similar to how the calendar is shown in the main app.
 * 
 * WIDGET FEATURES:
 * - Displays current active month with proper calendar grid
 * - Shows day numbers with today highlighted in gradient
 * - Indicates days with journal entries using colored dots
 * - Supports three widget sizes: small, medium, and large
 * - Uses consistent styling and colors from the main app
 * - Updates automatically to show current month
 * 
 * WIDGET SIZES:
 * - Small: Compact calendar grid with basic day indicators
 * - Medium: Standard calendar with weekday headers and content indicators
 * - Large: Enhanced calendar with year display and entry summary
 * 
 * DATA FLOW:
 * 1. Timeline Provider creates CalendarEntry objects with month data
 * 2. Widget View renders the appropriate size-specific layout
 * 3. Day cells show numbers, today highlighting, and content indicators
 * 4. Widget updates automatically based on timeline policy
 * 
 * STYLING:
 * - Uses the same color scheme as main app (logoBlue, logoTeal)
 * - Gradient backgrounds matching the main app design
 * - Proper spacing and typography for widget constraints
 * - Today's date highlighted with gradient circle
 * - Content indicators: teal dot for images, blue dot for audio
 * 
 * FUTURE ENHANCEMENTS:
 * - Real Firebase data integration (currently uses sample data)
 * - Image thumbnail loading and caching
 * - Deep linking to specific days in the main app
 * - Interactive elements for adding new entries
 */

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Data Models

/// Represents a journal entry for the widget (simplified version of main app's JournalEntry)
struct WidgetJournalEntry: Identifiable, Codable {
    let id: String?
    let date: Date
    let images: [String] // URLs of images
    let audioURL: String?
    
    /// Get the first image URL for thumbnail display
    var thumbnailURL: String? {
        images.first
    }
    
    /// Check if this entry has any content
    var hasContent: Bool {
        !images.isEmpty || audioURL != nil
    }
}

/// Timeline entry that contains the calendar data for the widget
struct CalendarEntry: TimelineEntry {
    let date: Date
    let currentMonth: Date
    let entries: [WidgetJournalEntry]
    let monthName: String
    let year: Int
}

// MARK: - Timeline Provider

/// Provides timeline data for the calendar widget
struct Provider: TimelineProvider {
    func getSnapshot(in context: Context, completion: @escaping @Sendable (CalendarEntry) -> Void) {
        let currentDate = Date()
        let currentMonth = startOfMonth(for: currentDate)
        
        let entry = CalendarEntry(
            date: currentDate,
            currentMonth: currentMonth,
            entries: [],
            monthName: monthYearString(from: currentMonth),
            year: Calendar.current.component(.year, from: currentMonth)
        )
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CalendarEntry>) -> Void) {
        let currentDate = Date()
        let currentMonth = startOfMonth(for: currentDate)
        
        // For now, we'll create a simple timeline that updates every hour
        // In a real implementation, you'd fetch data from Firebase here
        var entries: [CalendarEntry] = []
        
        // Create entries for the next 24 hours
        for hourOffset in 0..<24 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = CalendarEntry(
                date: entryDate,
                currentMonth: currentMonth,
                entries: [], // This would be populated from Firebase in a real implementation
                monthName: monthYearString(from: currentMonth),
                year: Calendar.current.component(.year, from: currentMonth)
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    typealias Entry = CalendarEntry
    
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(
            date: Date(),
            currentMonth: Date(),
            entries: [],
            monthName: "January",
            year: 2024
        )
    }
    
    // MARK: - Helper Methods
    
    /// Gets the start of the month for a given date
    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Formats a date as "Month Year" (e.g., "January 2024")
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Widget View

/// The main widget view that displays the calendar
struct rearviewWidgetEntryView: View {
    var entry: CalendarEntry
    @Environment(\.widgetFamily) var family
    
    // Widget-specific constants (similar to main app but optimized for widget space)
    private let logoBlue = Color(red: 67/255, green: 133/255, blue: 204/255)
    private let logoTeal = Color(red: 92/255, green: 184/255, blue: 178/255)
    
    var body: some View {
        ZStack {
            // Background gradient similar to main app
            LinearGradient(
                gradient: Gradient(colors: [
                    logoBlue.opacity(0.1),
                    logoTeal.opacity(0.05),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            default:
                mediumWidgetView
            }
        }
    }
    
    // MARK: - Widget Size Views
    
    /// Small widget view - compact calendar
    private var smallWidgetView: some View {
        VStack(spacing: 4) {
            // Month header
            Text(entry.monthName)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Compact calendar grid
            compactCalendarGrid
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    /// Medium widget view - standard calendar with thumbnails
    private var mediumWidgetView: some View {
        VStack(spacing: 6) {
            // Month header
            monthHeaderView
            
            // Weekday headers
            weekdayHeadersView
            
            // Calendar grid
            calendarGridView
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
    
    /// Large widget view - enhanced calendar with more details
    private var largeWidgetView: some View {
        VStack(spacing: 8) {
            // Month header with year
            largeMonthHeaderView
            
            // Weekday headers
            weekdayHeadersView
            
            // Calendar grid
            calendarGridView
            
            // Entry summary (if space allows)
            if !entry.entries.isEmpty {
                entrySummaryView
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Subviews
    
    /// Displays the month and year header for medium widgets
    private var monthHeaderView: some View {
        HStack {
            Text(entry.monthName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
        }
    }
    
    /// Displays the month and year header for large widgets
    private var largeMonthHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.monthName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(entry.year)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
    
    /// Displays the weekday headers (SUN, MON, etc.)
    private var weekdayHeadersView: some View {
        HStack(spacing: 0) {
            ForEach(["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 3)
        .padding(.bottom, 5)
    }
    
    /// Compact calendar grid for small widgets
    private var compactCalendarGrid: some View {
        let days = daysInMonth(for: entry.currentMonth)
        let firstWeekday = Calendar.current.component(.weekday, from: entry.currentMonth) - 1
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        let isCurrentMonth = Calendar.current.isDate(entry.currentMonth, equalTo: Date(), toGranularity: .month)
        
        return VStack(alignment: .leading) {
            LazyVGrid(columns: columns, spacing: 8) {
                // Empty spaces for days before the first day of the month
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Spacer()
                        .frame(height: 20)
                }
                
                // Days of the month
                ForEach(days, id: \.self) { date in
                    compactDayCellView(for: date)
                }
            }
        }
        .padding(.horizontal, isCurrentMonth ? 8 : 0)
        .padding(.bottom, isCurrentMonth ? 8 : 0)
        .padding(.top, isCurrentMonth ? 8 : 0)
        .background(
            isCurrentMonth ? 
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [logoBlue, logoTeal]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                ) : nil
        )
        .scaleEffect(isCurrentMonth ? 1.02 : 1.0)
    }
    
    /// Displays the calendar grid with days
    private var calendarGridView: some View {
        let days = daysInMonth(for: entry.currentMonth)
        let firstWeekday = Calendar.current.component(.weekday, from: entry.currentMonth) - 1
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        let isCurrentMonth = Calendar.current.isDate(entry.currentMonth, equalTo: Date(), toGranularity: .month)
        
        return VStack(alignment: .leading) {
            LazyVGrid(columns: columns, spacing: 15) {
                // Empty spaces for days before the first day of the month
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Spacer()
                        .frame(height: 35)
                }
                
                // Days of the month
                ForEach(days, id: \.self) { date in
                    dayCellView(for: date)
                }
            }
        }
        .padding(.horizontal, isCurrentMonth ? 16 : 0)
        .padding(.bottom, isCurrentMonth ? 16 : 0)
        .padding(.top, isCurrentMonth ? 16 : 0)
        .background(
            isCurrentMonth ? 
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [logoBlue, logoTeal]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                ) : nil
        )
        .scaleEffect(isCurrentMonth ? 1.02 : 1.0)
    }
    
    /// Entry summary for large widgets
    private var entrySummaryView: some View {
        HStack {
            Text("\(entry.entries.count) entries this month")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    /// Creates a compact day cell view for small widgets
    @ViewBuilder
    private func compactDayCellView(for date: Date) -> some View {
        let dayNumber = Calendar.current.component(.day, from: date)
        let isToday = Calendar.current.isDateInToday(date)
        let journalEntry = entryFor(date: date)
        let hasEntry = journalEntry != nil
        
        ZStack {
            // Thumbnail background if available
            if let journalEntry = journalEntry, let thumbnailURL = journalEntry.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipped()
                } placeholder: {
                    Color.gray.opacity(0.2)
                        .frame(width: 20, height: 20)
                }
            }
            
            // Today's gradient background
            if isToday {
                LinearGradient(
                    gradient: Gradient(colors: [logoBlue, logoTeal]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Circle())
                .frame(width: 18, height: 18)
            }
            
            // Day number
            Text("\(dayNumber)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.clear))
            
            // Content indicators for non-today days
            if !isToday, let journalEntry = journalEntry, journalEntry.hasContent {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        // Image indicator
                        if !journalEntry.images.isEmpty {
                            Circle()
                                .fill(logoTeal)
                                .frame(width: 4, height: 4)
                                .offset(x: 2, y: 2)
                        }
                        // Audio indicator
                        if journalEntry.audioURL != nil {
                            Circle()
                                .fill(logoBlue)
                                .frame(width: 3, height: 3)
                                .offset(x: -2, y: 2)
                        }
                    }
                }
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(!hasEntry && date < Date() ? 0.5 : 1.0)
    }
    
    /// Creates a day cell view with thumbnail if available
    @ViewBuilder
    private func dayCellView(for date: Date) -> some View {
        let dayNumber = Calendar.current.component(.day, from: date)
        let isToday = Calendar.current.isDateInToday(date)
        let journalEntry = entryFor(date: date)
        let hasEntry = journalEntry != nil
        
        ZStack {
            // Thumbnail background if available
            if let journalEntry = journalEntry, let thumbnailURL = journalEntry.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 64)
                        .clipped()
                } placeholder: {
                    Color.gray.opacity(0.2)
                        .frame(width: 44, height: 64)
                }
            }
            
            // Today's gradient background
            if isToday {
                LinearGradient(
                    gradient: Gradient(colors: [logoBlue, logoTeal]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Circle())
                .frame(width: 35, height: 35)
            }
            
            // Day number
            Text("\(dayNumber)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(width: 35, height: 35)
                .background(Circle().fill(Color.clear))
            
            // Content indicators for non-today days
            if !isToday, let journalEntry = journalEntry, journalEntry.hasContent {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        // Image indicator
                        if !journalEntry.images.isEmpty {
                            Circle()
                                .fill(logoTeal)
                                .frame(width: 6, height: 6)
                                .offset(x: 3, y: 3)
                        }
                        // Audio indicator
                        if journalEntry.audioURL != nil {
                            Circle()
                                .fill(logoBlue)
                                .frame(width: 4, height: 4)
                                .offset(x: -3, y: 3)
                        }
                    }
                }
            }
        }
        .frame(width: 44, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(!hasEntry && date < Date() ? 0.5 : 1.0)
    }
    
    // MARK: - Helper Methods
    
    /// Gets all days in the specified month
    private func daysInMonth(for date: Date) -> [Date] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: date) else { return [] }
        return range.compactMap { day in
            Calendar.current.date(byAdding: .day, value: day - 1, to: date)
        }
    }
    
    /// Finds the journal entry for a specific date
    private func entryFor(date: Date) -> WidgetJournalEntry? {
        let targetDate = Calendar.current.startOfDay(for: date)
        return entry.entries.first { journalEntry in
            Calendar.current.startOfDay(for: journalEntry.date) == targetDate
        }
    }
}

// MARK: - Widget Configuration

/// The main widget that displays the rearview calendar
struct rearviewWidget: Widget {
    let kind: String = "rearviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            rearviewWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("rearview Calendar")
        .description("View your journal calendar with daily entries and thumbnails")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview Data

/// Sample journal entries for previews
extension WidgetJournalEntry {
    static let sampleEntries: [WidgetJournalEntry] = [
        WidgetJournalEntry(
            id: "1",
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            images: ["https://example.com/image1.jpg"],
            audioURL: nil
        ),
        WidgetJournalEntry(
            id: "2", 
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            images: ["https://example.com/image2.jpg", "https://example.com/image3.jpg"],
            audioURL: "https://example.com/audio1.m4a"
        ),
        WidgetJournalEntry(
            id: "3",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            images: [],
            audioURL: "https://example.com/audio2.m4a"
        )
    ]
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    rearviewWidget()
} timeline: {
    CalendarEntry(
        date: Date.now,
        currentMonth: Date(),
        entries: WidgetJournalEntry.sampleEntries,
        monthName: "January 2024",
        year: 2024
    )
}

#Preview(as: .systemMedium) {
    rearviewWidget()
} timeline: {
    CalendarEntry(
        date: Date.now,
        currentMonth: Date(),
        entries: WidgetJournalEntry.sampleEntries,
        monthName: "January 2024",
        year: 2024
    )
}

#Preview(as: .systemLarge) {
    rearviewWidget()
} timeline: {
    CalendarEntry(
        date: Date.now,
        currentMonth: Date(),
        entries: WidgetJournalEntry.sampleEntries,
        monthName: "January 2024",
        year: 2024
    )
}
