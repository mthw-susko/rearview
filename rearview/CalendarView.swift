import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var authManager: FirebaseManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var guestModeManager: GuestModeManager
    @State private var showingAccountView = false
    @State private var showingNotificationTest = false
    
    @State private var hasScrolledToInitialMonth = false
    @State private var scrollToCurrentMonthTrigger = false
    @State private var isTitlePressed = false
    
    // Define colors from the logo for use in this view
    private let logoBlue = AppConstants.Colors.logoBlue
    private let logoTeal = AppConstants.Colors.logoTeal
    
    // State variables to control the gradient animation
    @State private var animateGradient = false
    @State private var pulseIntensity = 0.0
    @State private var refreshTrigger = UUID()
    
    private let calendar = Calendar.current
    
    private var currentDate: Date {
        Date()
    }
    
    private func scrollToCurrentMonth() {
        scrollToCurrentMonthTrigger.toggle()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        logoBlue.opacity(0.05 + pulseIntensity * 0.1),
                        logoTeal.opacity(0.02 + pulseIntensity * 0.05),
                        .black
                    ]),
                    startPoint: animateGradient ? .topLeading : .topTrailing,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    headerView
                        .padding(.horizontal)
                    
                    calendarScrollView
                }
            }
            .onAppear {
                if guestModeManager.isGuestMode {
                    // Guest mode - use a dummy userID
                    viewModel.fetchData(for: "guest")
                    if viewModel.monthsToDisplay.isEmpty {
                        viewModel.loadInitialMonths()
                    }
                    
                    // Request notification permissions for guest users
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                    
                    // Check and reschedule evening reminder for guest users
                    let today = Date()
                    let entry = viewModel.entryFor(date: today)
                    let hasCompletedEntryForToday = entry?.isCompleted ?? false
                    notificationManager.checkAndRescheduleReminder(for: "guest", hasEntryForToday: hasCompletedEntryForToday)
                } else if let userID = authManager.userSession?.uid {
                    viewModel.fetchData(for: userID)
                    if viewModel.monthsToDisplay.isEmpty {
                        viewModel.loadInitialMonths()
                    }
                    
                    // Check and reschedule evening reminder when app becomes active
                    let today = Date()
                    let entry = viewModel.entryFor(date: today)
                    let hasCompletedEntryForToday = entry?.isCompleted ?? false
                    notificationManager.checkAndRescheduleReminder(for: userID, hasEntryForToday: hasCompletedEntryForToday)
                }
                // Gradient direction animation
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
                
                // Subtle pulsing color intensity animation
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    pulseIntensity = 1.0
                }
                
                // Listen for app becoming active to refresh current day
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    refreshTrigger = UUID()
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
            .preferredColorScheme(.dark)
            .navigationDestination(for: Date.self) { date in
                DayView(date: date)
            }
            .sheet(isPresented: $showingAccountView) {
                EditAccountView()
            }
        }
        .environmentObject(viewModel)
    }

    private var calendarScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 30) {
                    ForEach(viewModel.monthsToDisplay, id: \.self) { monthDate in
                        monthView(for: monthDate)
                            .id(monthDate)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: viewModel.monthsToDisplay) { oldState, newState in
                if !hasScrolledToInitialMonth {
                    DispatchQueue.main.async {
                        let currentMonth = self.startOfMonth(for: Date())
                        // Use same positioning as rearview button
                        proxy.scrollTo(currentMonth, anchor: UnitPoint(x: 0.5, y: 0.1))
                        self.hasScrolledToInitialMonth = true
                    }
                }
            }
            .onChange(of: scrollToCurrentMonthTrigger) { _ in
                DispatchQueue.main.async {
                    let currentMonth = self.startOfMonth(for: self.currentDate)
                    // Scroll to show the month just below the header
                    proxy.scrollTo(currentMonth, anchor: UnitPoint(x: 0.5, y: 0.1))
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: {
                HapticManager.shared.impact(.light)
                scrollToCurrentMonth()
            }) {
                Text(AppConstants.Strings.appName)
                    .font(.largeTitle).fontWeight(.bold)
                    .foregroundColor(.white)
                    .scaleEffect(isTitlePressed ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isTitlePressed)
            }
            .buttonStyle(TitleButtonStyle(isPressed: $isTitlePressed))
            Spacer()
            
            // Notification settings button
            NavigationLink(destination: NotificationSettingsView()) {
                Image(systemName: "bell.badge")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.trailing, 8)
            
            Button(action: {
                HapticManager.shared.impact(.light)
                showingAccountView = true
            }) {
                if let image = getCurrentProfileImage() {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fill)
                        .frame(width: AppConstants.Dimensions.profileImageSize, height: AppConstants.Dimensions.profileImageSize).clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle).foregroundColor(.gray)
                }
            }
        }
        .padding(.top)
        .padding(.bottom, 5)
    }
    

    private func monthView(for firstDayOfMonth: Date) -> some View {
        let isCurrentMonth = calendar.isDate(firstDayOfMonth, equalTo: currentDate, toGranularity: .month)
        
        return VStack(alignment: .leading) {
            HStack {
                Text(monthYearString(from: firstDayOfMonth))
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .id(refreshTrigger) // Force refresh when app becomes active

            // Weekday headers for this month
            HStack {
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

            let days = daysInMonth(for: firstDayOfMonth)
            let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
            let columns = Array(repeating: GridItem(.flexible()), count: 7)

            LazyVGrid(columns: columns, spacing: 15) {
                // FIX: The weekday headers have been removed from here.
                ForEach(0..<firstWeekday, id: \.self) { _ in Spacer() }
                ForEach(days, id: \.self) { date in dayCell(for: date) }
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
        .animation(.easeInOut(duration: 0.3), value: isCurrentMonth)
    }

    // Helper function to get indicator color based on entry count
    private func indicatorColor(for entryCount: Int) -> Color {
        switch entryCount {
        case 1:
            return logoTeal.opacity(0.7)
        case 2:
            return logoTeal.opacity(0.85)
        case 3:
            return logoTeal
        case 4:
            // Blend between teal and blue - using predefined blend color
            return Color(red: 0.50, green: 0.62, blue: 0.75)
        default:
            // 5+ entries - use blue
            return logoBlue.opacity(0.9)
        }
    }
    
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let dayNumber = calendar.component(.day, from: date)
        let entry = viewModel.entryFor(date: date)
        let hasEntry = entry != nil
        let hasContent = entry?.hasContent ?? false
        let isToday = calendar.isDateInToday(date)
        let isSelectable = isToday || date < currentDate
        let hasHistoricalEntries = viewModel.hasEntriesFromPreviousYears(for: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let entryCount = viewModel.entryCountForDayAcrossYears(month: month, day: day)
        let indicatorColor = self.indicatorColor(for: entryCount)

        NavigationLink(value: date) {
            ZStack {
                if let entry = entry, let firstImage = entry.displayImages.first {
                    AsyncJournalImage(journalImage: firstImage, isThumbnail: true)
                } else if hasEntry && !hasContent {
                    // Show a subtle indicator for empty entries (days that had content before)
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: AppConstants.Dimensions.dayNumberSize, height: AppConstants.Dimensions.dayNumberSize)
                } else if !hasEntry && date < currentDate {
                    // Show a subtle indicator for past days without entries (can be selected)
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: AppConstants.Dimensions.dayNumberSize, height: AppConstants.Dimensions.dayNumberSize)
                }
                
                if isToday {
                     LinearGradient(
                         gradient: Gradient(colors: [logoBlue, logoTeal]),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing
                     )
                     .clipShape(Circle())
                     .frame(width: AppConstants.Dimensions.dayNumberSize, height: AppConstants.Dimensions.dayNumberSize)
                }
                
                Text("\(dayNumber)")
                    .font(.body).fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: AppConstants.Dimensions.dayNumberSize, height: AppConstants.Dimensions.dayNumberSize)
                    .background(Circle().fill(Color.clear))
                
                // Show indicator for days with historical entries in the top right corner
                if hasHistoricalEntries {
                    VStack {
                        HStack {
                            Spacer()
                            // Make the dot stand out more if there's an image thumbnail
                            if hasEntry && hasContent && entry?.displayImages.first != nil {
                                // Enhanced styling when image is present - color varies by entry count
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.25))
                                        .frame(width: 10, height: 10)
                                    Circle()
                                        .fill(indicatorColor)
                                        .frame(width: 7, height: 7)
                                }
                                .offset(x: -3, y: 3)
                            } else {
                                // Standard styling when no image - color varies by entry count
                                Circle()
                                    .fill(indicatorColor.opacity(0.8))
                                    .frame(width: 6, height: 6)
                                    .offset(x: -3, y: 3)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: AppConstants.Dimensions.dayCellSize, height: AppConstants.Dimensions.dayCellHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .simultaneousGesture(TapGesture().onEnded {
            if isSelectable {
                HapticManager.shared.impact(.light)
            }
        })
        .disabled(!isSelectable)
        .opacity(!isSelectable ? 0.5 : 1.0)
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "MMMM yyyy"; return formatter.string(from: date)
    }

    private func daysInMonth(for date: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
        return range.compactMap { day in calendar.date(byAdding: .day, value: day - 1, to: startOfMonth(for: date)) }
    }

    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }
    
    private func getCurrentProfileImage() -> UIImage? {
        if guestModeManager.isGuestMode {
            return guestModeManager.guestProfileImage
        } else {
            return authManager.profileImage
        }
    }
}

// Custom button style for the title with cool tap animation
struct TitleButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}
