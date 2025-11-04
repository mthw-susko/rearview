import SwiftUI
import FirebaseCore
import FirebaseAppCheck // Don't forget this import
import UserNotifications

// You can simplify the AppDelegate now
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // All Firebase setup is now in the App's initializer.
    // You can keep this file for other delegate methods if you need them.
    
    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = NotificationManager.shared
    
    return true
  }
}

@main
struct rearviewApp: App {
    // This connects the AppDelegate to your SwiftUI app lifecycle.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        // Define your App Check provider factory
        class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
          func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
            // Use App Attest for real devices, and Device Check for simulators
            #if targetEnvironment(simulator)
            return AppCheckDebugProvider(app: app)
            #else
            return AppAttestProvider(app: app)
            #endif
          }
        }

        // Set the factory *before* configuring Firebase
        AppCheck.setAppCheckProviderFactory(MyAppCheckProviderFactory())
        
        // Now, configure Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
