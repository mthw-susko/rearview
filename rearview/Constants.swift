//
//  Constants.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import SwiftUI
import AVFoundation

// MARK: - App Constants

struct AppConstants {
    
    // MARK: - Colors
    struct Colors {
        static let logoBlue = Color(red: 67/255, green: 133/255, blue: 204/255)
        static let logoTeal = Color(red: 92/255, green: 184/255, blue: 178/255)
        static let backgroundGradient = [logoBlue.opacity(0.1), Color.black]
        static let cardBackground = Color.white.opacity(0.1)
        static let textSecondary = Color.gray
        static let textPrimary = Color.white
    }
    
    // MARK: - Dimensions
    struct Dimensions {
        // Screen ratios
        static let imageViewHeightRatio: CGFloat = 0.7
        static let imageViewAspectRatio: CGFloat = 1.5 // Increased ratio for bigger photos
        static let maxImageViewWidth: CGFloat = 700 // Maximum width for image container (iPad constraint)
        static let profileImageSize: CGFloat = 40
        static let largeProfileImageSize: CGFloat = 120
        static let dayCellSize: CGFloat = 44
        static let dayCellHeight: CGFloat = 64
        static let dayNumberSize: CGFloat = 35
        static let buttonSize: CGFloat = 44
        static let smallButtonSize: CGFloat = 30
        
        // Spacing
        static let defaultPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 30
        static let cardCornerRadius: CGFloat = 10
        static let circleCornerRadius: CGFloat = 20
        
        // Image processing
        static let maxImageDimension: CGFloat = 1080
        static let imageCompressionQuality: CGFloat = 0.9
        static let profileImageCompressionQuality: CGFloat = 0.8
        static let profileImageMaxDimension: CGFloat = 500
    }
    
    // MARK: - Strings
    struct Strings {
        // App
        static let appName = "rearview"
        static let welcomeBack = "Welcome Back"
        static let createAccount = "Create Account"
        static let signInSubtitle = "Sign in to access your journal."
        static let signUpSubtitle = "Create a new account to save your memories."
        
        // Navigation
        static let done = "Done"
        static let cancel = "Cancel"
        static let delete = "Delete"
        static let save = "Save"
        
        // Journal
        static let noEntryForDay = "No entry for this day."
        static let tapToAddPhotos = "Tap to add photos"
        static let addPhotos = "Add Photos"
        
        // Account
        static let account = "Account"
        static let updateEmail = "Update Email"
        static let newEmail = "New Email"
        static let saveEmail = "Save Email"
        static let actions = "Actions"
        static let sendPasswordReset = "Send Password Reset"
        static let signOut = "Sign Out"
        static let deleteAccount = "Delete Account"
        
        // Audio
        static let recording = "Recording"
        static let playing = "Playing"
        static let paused = "Paused"
        
        // Errors
        static let error = "Error"
        static let success = "Success"
        static let emailUpdated = "Your email has been updated."
        static let deleteAccountWarning = "This will permanently delete your account and all of your data. This action cannot be undone."
        static let areYouSure = "Are you sure?"
        
        // Terms
        static let termsText = "I agree to the"
        static let andText = "and"
        static let dontHaveAccount = "Don't have an account?"
        static let signUp = "Sign Up"
        static let alreadyHaveAccount = "Already have an account?"
        static let signIn = "Sign In"
        
        // Notifications
        static let eveningReminderTitle = "Time to journal! 📝"
        static let eveningReminderBody = "Don't forget to add photos or audio to today's journal entry"
        static let notificationPermissionTitle = "Enable Notifications"
        static let notificationPermissionMessage = "Allow rearview to send you reminders to add content to your journal entries"
    }
    
    // MARK: - URLs
    struct URLs {
        static let termsAndConditions = "https://doc-hosting.flycricket.io/rearview-terms-and-conditions/7891e804-b4d7-4c6a-a35d-d3f98260ded0/terms"
        static let privacyPolicy = "https://doc-hosting.flycricket.io/rearview-privacy-policy/be34945b-766e-4432-85c0-bcfe88eaffbf/privacy"
    }
    
    // MARK: - Audio Settings
    struct Audio {
        static let sampleRate: Double = 12000
        static let numberOfChannels: Int = 1
        static let quality = AVAudioQuality.medium
        static let fileExtension = "m4a"
        static let maxFileSize: Int = 5 * 1024 * 1024 // 5MB
    }
    
    // MARK: - Animation
    struct Animation {
        static let defaultDuration: Double = 0.2
        static let gradientDuration: Double = 5.0
        static let hapticDelay: Double = 0.5
    }
    
    // MARK: - Firebase
    struct Firebase {
        static let usersCollection = "users"
        static let entriesCollection = "entries"
        static let profileImagesPath = "profile_images"
        static let dateFormat = "yyyy-MM-dd"
    }
}

// MARK: - Extensions for easier access

extension Color {
    static let appBlue = AppConstants.Colors.logoBlue
    static let appTeal = AppConstants.Colors.logoTeal
    static let appBackground = AppConstants.Colors.backgroundGradient
    static let appCardBackground = AppConstants.Colors.cardBackground
    static let appTextSecondary = AppConstants.Colors.textSecondary
    static let appTextPrimary = AppConstants.Colors.textPrimary
}

extension CGFloat {
    static let defaultPadding = AppConstants.Dimensions.defaultPadding
    static let smallPadding = AppConstants.Dimensions.smallPadding
    static let largePadding = AppConstants.Dimensions.largePadding
    static let cardCornerRadius = AppConstants.Dimensions.cardCornerRadius
    static let circleCornerRadius = AppConstants.Dimensions.circleCornerRadius
}
