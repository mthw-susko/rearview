import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct DayView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: CalendarViewModel
    @EnvironmentObject var authManager: FirebaseManager
    @EnvironmentObject var permissionManager: PermissionManager
    
    let date: Date
    
    private let logoBlue = AppConstants.Colors.logoBlue
    private let logoTeal = AppConstants.Colors.logoTeal
    
    // Year navigation state - initialize to the passed date's year
    @State private var selectedYear: Int = 0
    
    // Get available years for this month/day combination
    private var availableYears: [Int] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let allEntries = viewModel.entriesForDayAcrossYears(month: month, day: day)
        let years = allEntries.map { $0.year }
        let currentYear = calendar.component(.year, from: Date())
        let isFutureDate = calendar.component(.year, from: date) > currentYear || 
                          (calendar.component(.year, from: date) == currentYear && date > Date())
        
        var uniqueYears = Set(years)
        // Only include current year if the date is not in the future (to prevent adding entries to future dates)
        if !isFutureDate {
            uniqueYears.insert(currentYear)
        }
        return Array(uniqueYears).sorted(by: >)
    }
    
    // Check if the original date (from calendar) is in the future
    private var isOriginalDateInFuture: Bool {
        return date > Date()
    }
    
    // Check if the selected date is in the future (to prevent adding content)
    private var isSelectedDateInFuture: Bool {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let selectedYear = self.selectedYear
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        if selectedYear > currentYear {
            return true
        } else if selectedYear == currentYear {
            if let selectedDate = calendar.date(from: DateComponents(year: selectedYear, month: month, day: day)) {
                return selectedDate > Date()
            }
        }
        return false
    }
    
    // Check if we should prevent adding content (either original date or selected date is in future)
    private var shouldPreventAddingContent: Bool {
        return isOriginalDateInFuture || isSelectedDateInFuture
    }
    
    // Computed date for the selected year
    private var selectedDate: Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return calendar.date(from: DateComponents(year: selectedYear, month: month, day: day)) ?? date
    }
    
    private var entry: JournalEntry {
        let foundEntry = viewModel.entryFor(date: selectedDate) ?? JournalEntry(id: nil, date: selectedDate, audioURL: nil, images: [])
        print("DayView: entry for date \(selectedDate) - images: \(foundEntry.images.count), displayImages: \(foundEntry.displayImages.count), audioURL: \(foundEntry.audioURL ?? "nil")")
        return foundEntry
    }
    
    @State private var selectedImageIndex = 0
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    @State private var isUploadingImages = false
    @State private var isUploadingAudio = false
    @State private var showingFullscreenImage = false
    @State private var showingPhotoMenu = false
    @State private var showingSlidingButtons = false
    @State private var showingAudioOptions = false
    @State private var showingAudioMenu = false
    @State private var showingYearPicker = false
    @StateObject private var cameraService = CameraService.shared
        
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [logoBlue.opacity(0.2), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                headerView
                
                if entry.displayImages.isEmpty {
                    emptyStateView
                } else {
                    imageTabView
                }
                
                Spacer()
                audioPlayerView.padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            // Initialize selectedYear - if date is in future and has historical entries, show most recent past year
            let calendar = Calendar.current
            let dateYear = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: Date())
            let isFutureDate = dateYear > currentYear || (dateYear == currentYear && date > Date())
            
            if isFutureDate && !availableYears.isEmpty {
                // If it's a future date, default to the most recent past year (first in sorted list)
                // availableYears is sorted descending, so first item is most recent
                if let mostRecentPastYear = availableYears.first(where: { $0 < currentYear }) {
                    selectedYear = mostRecentPastYear
                } else {
                    selectedYear = dateYear
                }
            } else {
                selectedYear = dateYear
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Swipe from left to right to go back
                    if value.translation.width > 100 && abs(value.translation.height) < 100 {
                        HapticManager.shared.impact(.light)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onChange(of: selectedPhotoItems) { newItems in
            if !newItems.isEmpty {
                HapticManager.shared.impact(.medium)
            }
            Task {
                await processSelectedPhotos(newItems)
            }
        }
        .sheet(isPresented: $showingFullscreenImage) {
            FullscreenImageView(images: entry.displayImages, selectedIndex: $selectedImageIndex)
        }
        .fullScreenCover(isPresented: $cameraService.isShowingCamera) {
            CameraSheetView(cameraService: cameraService)
        }
        .onChange(of: cameraService.capturedImage) { newImage in
            if let image = newImage {
                Task {
                    await processCapturedImage(image)
                }
            }
        }
        .onTapGesture {
            if showingAudioMenu {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingAudioMenu = false
                }
            }
        }
        .overlay(
            // Custom dropdown menu overlay
            Group {
                if showingAudioMenu {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 0) {
                                Button(action: {
                                    if shouldPreventAddingContent {
                                        // Don't allow appending to future dates
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showingAudioMenu = false
                                        }
                                        return
                                    }
                                    if let audioURLString = entry.audioURL, let url = URL(string: audioURLString) {
                                        if permissionManager.validateMicrophonePermission() {
                                            HapticManager.shared.impact(.heavy)
                                            audioRecorder.startAppending(to: url)
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                showingAudioMenu = false
                                            }
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle")
                                        Text("Append Recording")
                                        Spacer()
                                    }
                                    .foregroundColor(shouldPreventAddingContent ? .gray : .white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .disabled(shouldPreventAddingContent)
                                
                                Divider().background(Color.gray.opacity(0.3))
                                
                                Button(action: {
                                    HapticManager.shared.play(.warning)
                                    let userID = authManager.userSession?.uid ?? "guest"
                                    Task { await viewModel.deleteAudio(for: selectedDate, userID: userID) }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showingAudioMenu = false
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete Recording")
                                        Spacer()
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(Color.black.opacity(0.9))
                            .cornerRadius(12)
                            .frame(width: 200)
                            .shadow(radius: 10)
                            .offset(y: -80)
                        }
                    }
                }
            }
        )
    }
    
    private var imageTabView: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedImageIndex) {
                ForEach(entry.displayImages.indices, id: \.self) { index in
                    ZStack {
                        Color.black
                        AsyncJournalImage(journalImage: entry.displayImages[index])
                            .id(entry.displayImages[index].id) // Use just the image ID for proper recycling
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped() // Ensure content is clipped to bounds
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .overlay(controlsOverlay, alignment: .bottom)
            .overlay(trashOverlay, alignment: .topTrailing)
            .clipped() // Additional clipping at TabView level
            .onTapGesture {
                if !entry.displayImages.isEmpty {
                    showingFullscreenImage = true
                }
            }
        }
        .frame(height: responsiveImageHeight)
        .frame(maxWidth: AppConstants.Dimensions.maxImageViewWidth) // Constrain width for iPad
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16) // Only horizontal padding for image container
        .padding(.vertical, 20) // Separate vertical padding
    }
    
    // MARK: - Responsive Sizing
    
    private var responsiveImageHeight: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Determine if we're on iPad based on screen size and device type
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad || screenWidth > 768 || screenHeight > 1024
        
        if isIPad {
            // For iPad: Use most of the available space, extending down to audio controls
            let safeAreaTop: CGFloat
            if #available(iOS 15.0, *) {
                safeAreaTop = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first?.safeAreaInsets.top ?? 0
            } else {
                safeAreaTop = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
            }
            
            let headerHeight: CGFloat = 60 // Approximate header height
            let audioControlsHeight: CGFloat = 120 // Approximate audio controls height
            let padding: CGFloat = 20 // Reduced vertical padding for larger images
            
            let availableHeight = screenHeight - safeAreaTop - headerHeight - audioControlsHeight - padding
            let calculatedHeight = min(screenWidth, AppConstants.Dimensions.maxImageViewWidth) * AppConstants.Dimensions.imageViewAspectRatio
            
            // Use the larger of calculated height or available height (up to a reasonable max)
            let maxHeight = min(availableHeight, 1000) // Increased cap to 800 points
            return min(max(calculatedHeight, availableHeight * 0.8), maxHeight)
        } else {
            // For iPhone: Use the original calculation
            return min(screenWidth, AppConstants.Dimensions.maxImageViewWidth) * AppConstants.Dimensions.imageViewAspectRatio
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack {
            if isSelectedDateInFuture {
                // Show message for future dates - can't add content
                VStack(spacing: 15) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("View Only")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("You can view past entries for this date, but cannot add new content to future dates")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if permissionManager.hasPhotoLibraryAccess || permissionManager.hasCameraAccess {
                // Show both camera and photo library options stacked vertically
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text("Tap To")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 15) {
                        // Take Photo Button
                        if permissionManager.hasCameraAccess {
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                cameraService.presentCamera()
                            }) {
                                VStack(spacing: 15) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 50))
                                    Text("Take Photo")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.gray)
                            }
                        }
                        
                        // "or" divider
                        if permissionManager.hasCameraAccess && permissionManager.hasPhotoLibraryAccess {
                            Text("or")
                                .font(.headline)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        
                        // Add Photo Button
                        if permissionManager.hasPhotoLibraryAccess {
                            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                                VStack(spacing: 15) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 50))
                                    Text(AppConstants.Strings.addPhotos)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show permission message
                VStack(spacing: 15) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 8) {
                        Text("Photo Access Required")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Enable photo and camera access to add photos to your journal entries")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button("Enable Access") {
                            permissionManager.showAllPermissionsAlert()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: responsiveImageHeight)
        .frame(maxWidth: AppConstants.Dimensions.maxImageViewWidth) // Constrain width for iPad
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
    
    @MainActor
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        guard !shouldPreventAddingContent else {
            print("DayView: Cannot add images to future dates")
            selectedPhotoItems = []
            return
        }
        print("DayView: Processing \(items.count) selected photos...")
        isUploadingImages = true
        
        // Use guest userID if in guest mode, otherwise use authenticated userID
        let userID = authManager.userSession?.uid ?? "guest"
        print("DayView: Using userID: \(userID)")

        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    do {
                        if let data = try await item.loadTransferable(type: Data.self) {
                            print("DayView: Successfully loaded image data, size: \(data.count) bytes")
                            await viewModel.addImage(to: date, imageData: data, for: userID)
                        } else {
                            print("DayView: Failed to load image data from PhotosPickerItem")
                        }
                    } catch {
                        print("DayView: Failed to load image data: \(error)")
                    }
                }
            }
        }
        
        if !Task.isCancelled {
            selectedPhotoItems = []
            isUploadingImages = false
            HapticManager.shared.play(.success)
            print("DayView: Image processing completed")
        }
    }
    
    @MainActor
    private func processCapturedImage(_ image: UIImage) async {
        guard !shouldPreventAddingContent else {
            print("DayView: Cannot add images to future dates")
            cameraService.resetCapturedImage()
            return
        }
        print("DayView: Processing captured image...")
        isUploadingImages = true
        
        // Use guest userID if in guest mode, otherwise use authenticated userID
        let userID = authManager.userSession?.uid ?? "guest"
        print("DayView: Using userID: \(userID)")
        
        // Convert UIImage to Data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("DayView: Failed to convert captured image to data")
            isUploadingImages = false
            return
        }
        
        await viewModel.addImage(to: date, imageData: imageData, for: userID)
        
        isUploadingImages = false
        HapticManager.shared.play(.success)
        cameraService.resetCapturedImage()
        print("DayView: Captured image processing completed")
    }

    private var headerView: some View {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let currentYearIndex = availableYears.firstIndex(of: selectedYear) ?? 0
        let canNavigateToPreviousYear = currentYearIndex < availableYears.count - 1
        let canNavigateToNextYear = currentYearIndex > 0
        
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.dateFormat = "MMMM d"
        
        // Number formatter to ensure year displays without commas
        let yearFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            formatter.usesGroupingSeparator = false
            return formatter
        }()
        
        func formatYear(_ year: Int) -> String {
            return yearFormatter.string(from: NSNumber(value: year)) ?? String(year)
        }
        
        return HStack {
            Button(action: {
                HapticManager.shared.impact(.light)
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.left")
            }
            Spacer()
            
            // Date with year picker dropdown
            Menu {
                ForEach(availableYears, id: \.self) { year in
                    Button(action: {
                        selectedYear = year
                        HapticManager.shared.impact(.light)
                    }) {
                        HStack {
                            Text(formatYear(year))
                            if year == selectedYear {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    // Format date manually to avoid number formatting on year
                    let monthDay = monthDayFormatter.string(from: selectedDate)
                    let yearString = formatYear(selectedYear)
                    Text(monthDay + ", " + yearString)
                        .fontWeight(.bold)
                    
                    if availableYears.count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .foregroundColor(.white)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            // Horizontal swipe
                            if value.translation.width > 0 && canNavigateToPreviousYear {
                                // Swipe right - go to previous year (earlier year)
                                let nextIndex = currentYearIndex + 1
                                if nextIndex < availableYears.count {
                                    selectedYear = availableYears[nextIndex]
                                    HapticManager.shared.impact(.light)
                                }
                            } else if value.translation.width < 0 && canNavigateToNextYear {
                                // Swipe left - go to next year (later year)
                                let nextIndex = currentYearIndex - 1
                                if nextIndex >= 0 {
                                    selectedYear = availableYears[nextIndex]
                                    HapticManager.shared.impact(.light)
                                }
                            }
                        }
                    }
            )
            
            Spacer()
            Image(systemName: "arrow.left").opacity(0)
        }
        .font(.title2).foregroundColor(.white).padding()
    }
    
    @ViewBuilder
    private var trashOverlay: some View {
        if !entry.displayImages.isEmpty {
            Button(action: {
                HapticManager.shared.play(.warning)
                Task {
                    guard entry.displayImages.indices.contains(selectedImageIndex) else { return }
                    let userID = authManager.userSession?.uid ?? "guest"
                    let imageToDelete = entry.displayImages[selectedImageIndex]
                    await viewModel.deleteImage(from: selectedDate, journalImage: imageToDelete, for: userID)
                }
            }) {
                Image(systemName: "xmark")
                    .fontWeight(.bold)
            }
            .buttonStyle(TransparentCircleButtonStyle())
            .font(.headline)
            .padding(.top, 20) // Closer to top edge
            .padding(.trailing, 20) // Closer to right edge
        }
    }
    
    @ViewBuilder
    private var controlsOverlay: some View {
        HStack(alignment: .bottom) {
            // Page indicator (dots) on the left
            if entry.displayImages.count > 1 {
                HStack(spacing: 8) {
                    ForEach(entry.displayImages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(20)
            }
            
            Spacer()
            
            // Sliding buttons container - positioned to avoid right padding issues
            VStack(spacing: 12) {
                // Camera and Photo buttons that slide down
                if showingSlidingButtons && !isSelectedDateInFuture {
                    // Camera button
                    Button(action: {
                        if permissionManager.validateCameraPermission() {
                            HapticManager.shared.impact(.medium)
                            cameraService.presentCamera()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingSlidingButtons = false
                            }
                        }
                    }) {
                        Image(systemName: "camera")
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .disabled(isUploadingImages)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    
                    // Photo library button
                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .disabled(isUploadingImages)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
                
                // Plus button - only show if not viewing a future date
                if !isSelectedDateInFuture {
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingSlidingButtons.toggle()
                        }
                    }) {
                        ZStack {
                            if isUploadingImages {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: showingSlidingButtons ? "xmark" : "plus")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .font(.title2)
                    .buttonStyle(CircleButtonStyle())
                    .disabled(isUploadingImages)
                }
            }
            .frame(width: 50) // Fixed width to prevent horizontal movement
            .frame(maxWidth: .infinity, alignment: .trailing) // Align to right edge
        }
        .padding(.horizontal, 20) // Fixed horizontal padding
        .padding(.bottom, 20) // Closer to bottom edge
    }

    @ViewBuilder
    private var audioPlayerView: some View {
        HStack(spacing: 4) { // Reduced spacing to hug the sides
            if isUploadingAudio {
                ProgressView().tint(.white).frame(height: 50)
            } else if let audioURLString = entry.audioURL, let url = URL(string: audioURLString) {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    if audioPlayer.isPlaying { 
                        audioPlayer.pausePlayback() 
                    } else if audioRecorder.isRecording {
                        // Stop recording (either new or appending)
                        if shouldPreventAddingContent {
                            // Don't allow saving audio to future dates
                            audioRecorder.stopRecording()
                            return
                        }
                        if let url = audioRecorder.stopRecording() {
                            let userID = authManager.userSession?.uid ?? "guest"
                            isUploadingAudio = true
                            Task {
                                if audioRecorder.isAppending {
                                    await viewModel.appendAudio(for: date, audioURL: url, for: userID)
                                } else {
                                    await viewModel.setAudio(for: date, audioURL: url, for: userID)
                                }
                                isUploadingAudio = false
                                HapticManager.shared.play(.success)
                            }
                        }
                    } else { 
                        audioPlayer.startPlayback(url: url) 
                    }
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : (audioPlayer.isPlaying ? "pause.fill" : "play.fill"))
                        .font(.title).foregroundColor(audioRecorder.isRecording ? .red : .white)
                }
                .frame(width: 44) // Fixed width for button
                
                ModernSoundWaveView(amplitude: CGFloat(audioRecorder.isRecording ? audioRecorder.audioPower : audioPlayer.audioPower))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity) // Takes all remaining space
                
                // Audio options button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingAudioMenu.toggle()
                    }
                }) {
                    Image(systemName: "ellipsis").font(.title).foregroundColor(.white)
                }
                .frame(width: 44) // Fixed width for button
            } else {
                Button(action: {
                    if shouldPreventAddingContent {
                        // Don't allow recording for future dates
                        return
                    }
                    if audioRecorder.isRecording {
                        HapticManager.shared.impact(.medium)
                        if let url = audioRecorder.stopRecording() {
                            let userID = authManager.userSession?.uid ?? "guest"
                            isUploadingAudio = true
                            Task {
                                if audioRecorder.isAppending {
                                    await viewModel.appendAudio(for: date, audioURL: url, for: userID)
                                } else {
                                    await viewModel.setAudio(for: date, audioURL: url, for: userID)
                                }
                                isUploadingAudio = false
                                HapticManager.shared.play(.success)
                            }
                        }
                    } else {
                        print("DayView: Attempting to start recording, checking microphone permission...")
                        if permissionManager.validateMicrophonePermission() {
                            print("DayView: Microphone permission granted, starting recording...")
                            HapticManager.shared.impact(.heavy)
                            audioRecorder.startRecording()
                        } else {
                            print("DayView: Microphone permission denied")
                        }
                    }
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : (audioRecorder.isAppending ? "plus.mic.fill" : "mic.fill"))
                        .font(.title).foregroundColor(audioRecorder.isRecording ? .red : (shouldPreventAddingContent ? .gray : .white))
                }
                .frame(width: 44) // Fixed width for button
                .disabled(shouldPreventAddingContent)
                
                ModernSoundWaveView(amplitude: CGFloat(audioRecorder.audioPower))
                    .frame(height: 50)
                    .frame(maxWidth: .infinity) // Takes all remaining space
            }
        }
        .padding(.horizontal, 16) // Add padding to match image container
    }
}

struct FullscreenImageView: View {
    let images: [JournalImage]
    @Binding var selectedIndex: Int
    @Environment(\.presentationMode) var presentationMode
    @State private var currentIndex: Int
    
    init(images: [JournalImage], selectedIndex: Binding<Int>) {
        self.images = images
        self._selectedIndex = selectedIndex
        self._currentIndex = State(initialValue: selectedIndex.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    AsyncJournalImage(journalImage: images[index])
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button("Done") {
                        selectedIndex = currentIndex
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) of \(images.count)")
                        .foregroundColor(.white)
                        .padding()
                }
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}


