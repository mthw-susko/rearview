import UIKit

// A centralized manager for providing haptic feedback.
// Using a singleton pattern to ensure a single instance is used throughout the app.
class HapticManager {
    
    static let shared = HapticManager()
    
    private init() { }

    /// Triggers a notification feedback, ideal for indicating success, warnings, or errors.
    /// - Parameter type: The type of notification to convey.
    func play(_ feedback: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(feedback)
    }

    /// Triggers an impact feedback, ideal for taps and light interactions.
    /// - Parameter style: The intensity of the impact (e.g., .light, .medium, .heavy).
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

