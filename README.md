# rearview

A beautiful iOS journaling app that lets you capture your daily memories through photos and audio recordings. Built with SwiftUI and Firebase, rearview offers a unique multi-year journal experience that helps you reflect on your past and build a visual story of your life.

## 📱 Features

### Core Functionality
- **Multi-Year Journal**: Create entries for any day and view entries from previous years on the same date
- **Photo Journaling**: Add multiple photos per day to create a visual narrative
- **Audio Recordings**: Capture your thoughts and feelings with voice recordings
- **Calendar View**: Beautiful month-by-month calendar displaying the current year with visual indicators
- **Historical Entry Navigation**: Easy year navigation to view and compare entries across different years
- **Visual Indicators**: Colored borders on calendar days indicate entries from previous years, with color intensity based on the number of historical entries

### User Experience
- **Firebase Authentication**: Secure sign-up and sign-in with email/password
- **Guest Mode**: Try the app without an account using local-only storage
- **Evening Reminders**: Gentle push notifications to remind you to add content to your journal
- **Account Management**: Update email, reset password, and manage your account settings
- **Haptic Feedback**: Subtle haptic feedback for better user interaction
- **Optimistic UI Updates**: Images appear instantly while uploading in the background

## 🏗️ Architecture

### Tech Stack
- **SwiftUI**: Modern declarative UI framework
- **Firebase**: 
  - Authentication for user management
  - Firestore for real-time database
  - Storage for images and audio files
  - App Check for security
  - Analytics and Crashlytics
- **WidgetKit**: iOS home screen widgets
- **AVFoundation**: Audio recording and playback

### Project Structure
```
rearview/
├── rearview/                  # Main app
│   ├── CalendarView.swift     # Main calendar grid view
│   ├── DayView.swift          # Detailed day view with year navigation
│   ├── DataModels.swift       # JournalEntry, CalendarViewModel
│   ├── ContentView.swift      # Root view with navigation logic
│   ├── AuthenticationView.swift
│   ├── WelcomeView.swift      # Onboarding experience
│   ├── FirebaseManager.swift  # Firebase authentication
│   ├── AudioService.swift     # Audio recording/playback
│   ├── CameraService.swift    # Photo capture
│   ├── NotificationManager.swift
│   ├── GuestModeManager.swift # Guest mode functionality
│   └── Constants.swift        # App-wide constants
├── rearviewWidget/            # iOS widget extension
└── rearview.xcodeproj/
```

### Key Design Patterns
- **MVVM Architecture**: ViewModels manage state and business logic
- **State Management**: `@StateObject`, `@EnvironmentObject`, and `@State` for reactive UI
- **Real-time Updates**: Firestore snapshot listeners for live data synchronization
- **Optimistic UI**: Immediate feedback with background synchronization

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later (for development)
- Firebase project configured
- `GoogleService-Info.plist` added to the project

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rearview
   ```

2. **Open in Xcode**
   ```bash
   open rearview.xcodeproj
   ```

3. **Configure Firebase**
   - Add your `GoogleService-Info.plist` to the `rearview/` directory
   - Ensure Firebase is properly configured in `rearviewApp.swift`

4. **Configure App Check** (Optional but recommended)
   - Set up App Attest for production
   - Use App Check Debug Provider for development/simulator

5. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd+R` to build and run

### Required Permissions
The app requests the following permissions:
- **Photo Library**: To select and save photos
- **Camera**: To capture photos
- **Microphone**: To record audio
- **Notifications**: For evening reminders

## 📖 Usage

### Creating Journal Entries
1. Navigate to any day in the current year's calendar
2. Tap on a day to open the day view
3. Add photos by tapping the camera or photo button
4. Record audio by tapping the microphone button
5. Photos and audio are automatically saved to Firebase

### Viewing Historical Entries
1. Days with entries from previous years display a colored border
2. The border color intensity indicates how many years have entries for that date
3. Tap on a day to view current year's entry
4. Use the year dropdown menu in the day view header to navigate to previous years
5. Swipe left/right on the header for quick year navigation

### Guest Mode
- Try the app without creating an account
- All data is stored locally on your device
- Switch to account mode anytime to sync data to the cloud

### Widget Setup
1. Long press on your home screen
2. Tap the "+" button to add widgets
3. Search for "rearview"
4. Choose your preferred widget size
5. The widget will display your current month calendar with entry indicators

## 🎨 Design Principles

### Color Scheme
- **Logo Blue**: `#4385CC` - Primary brand color
- **Logo Teal**: `#5CB8B2` - Secondary brand color
- **Gradient Backgrounds**: Subtle gradients using brand colors

### Visual Indicators
- **Today**: Gradient circle highlight
- **Past Entries**: Subtle circle indicators
- **Historical Entries**: Colored border (teal to blue gradient based on entry count)
- **Content Indicators**: 
  - Teal dot for images
  - Blue dot for audio

## 🔒 Security & Privacy

- **Firebase App Check**: Protects backend resources from abuse
- **Secure Authentication**: Firebase Authentication with email/password
- **Encrypted Storage**: Firebase Storage for secure file storage
- **Data Privacy**: All user data is stored securely in Firebase

## 🧪 Testing

The project includes:
- Unit tests (`rearviewTests/`)
- UI tests (`rearviewUITests/`)

Run tests with `Cmd+U` in Xcode.

## 📝 Development Notes

### Image Upload Flow
1. User selects/captures image
2. Image appears immediately in UI (optimistic update)
3. Image uploads to Firebase Storage in background
4. Firestore entry is updated with remote URL
5. Local temporary image is replaced with remote URL

### Multi-Year Journal Logic
- Calendar displays only the current year (12 months)
- Days are selectable if they're today, in the past, or have historical entries
- Historical entry detection checks for entries with same month/day but earlier year
- Border color varies based on total entry count across all years

### Future Date Restrictions
- Users cannot create new entries for future dates
- Historical entries from past years are viewable even if the date hasn't occurred this year
- Year dropdown excludes current year for future dates to prevent accidental entry creation

## 🤝 Contributing

This is a personal project. If you'd like to contribute or report issues, please open an issue or submit a pull request.

## 📄 License

[Add your license information here]

## 👤 Author

**Matthew Susko**

---

Built with ❤️ using SwiftUI and Firebase
