import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = FirebaseManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    @StateObject private var guestModeManager = GuestModeManager.shared
    @State private var hasRequestedPermissions = false
    @State private var showingWelcome = false
    @State private var shouldShowSignUp = false
    @State private var showingGuestSetup = false

    var body: some View {
        Group {
            if authManager.isInitializing {
                LoadingScreen()
            } else if showingWelcome {
                WelcomeView(showingWelcome: $showingWelcome) {
                    shouldShowSignUp = true
                }
            } else if showingGuestSetup {
                GuestSetupView(showingWelcome: $showingWelcome)
            } else if authManager.userSession == nil && !guestModeManager.isGuestMode {
                AuthenticationView(initialSignUpState: shouldShowSignUp)
            } else {
                CalendarView()
            }
        }
        .environmentObject(authManager)
        .environmentObject(notificationManager)
        .environmentObject(permissionManager)
        .environmentObject(guestModeManager)
        .onAppear {
            // Check if this is the first launch
            if !UserDefaultsManager.shared.hasLaunchedBefore {
                showingWelcome = true
                UserDefaultsManager.shared.markAsLaunched()
            }
            
            // Request all permissions immediately when user is signed in
            if authManager.userSession != nil && !hasRequestedPermissions {
                Task {
                    await requestAllPermissions()
                    hasRequestedPermissions = true
                }
            }
        }
        .onChange(of: authManager.userSession) { _, newSession in
            // Reset signup flag when user successfully authenticates
            if newSession != nil {
                shouldShowSignUp = false
            }
            
            if newSession != nil && !hasRequestedPermissions {
                Task {
                    await requestAllPermissions()
                    hasRequestedPermissions = true
                }
            }
            
            // When user signs out, disable guest mode to show sign-in screen
            if newSession == nil {
                guestModeManager.disableGuestModeForSignIn()
                // Clear the CalendarViewModel data to prevent mixing
                // The CalendarViewModel will be recreated when CalendarView appears
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Clear app badge when app becomes active
            notificationManager.clearAppBadge()
        }
        .alert("Permission Required", isPresented: $permissionManager.showingPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionManager.permissionAlertMessage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestAllPermissions() async {
        // Request notification permission
        await notificationManager.requestAuthorization()
        
        // Request photo and microphone permissions
        await permissionManager.requestAllPermissions()
    }
}

#Preview {
    ContentView()
}

