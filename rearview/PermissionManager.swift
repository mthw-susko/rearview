//
//  PermissionManager.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import Foundation
import Photos
import AVFoundation
import SwiftUI

/// Manages photo library and microphone permissions
@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published var microphoneStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var showingPermissionAlert = false
    @Published var permissionAlertMessage = ""
    
    private init() {
        checkCurrentPermissions()
    }
    
    // MARK: - Permission Checking
    
    /// Checks current permission status for photo library, microphone, and camera
    func checkCurrentPermissions() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    /// Checks if photo library access is granted
    var hasPhotoLibraryAccess: Bool {
        return photoLibraryStatus == .authorized || photoLibraryStatus == .limited
    }
    
    /// Checks if microphone access is granted
    var hasMicrophoneAccess: Bool {
        return microphoneStatus == .granted
    }
    
    /// Checks if camera access is granted
    var hasCameraAccess: Bool {
        return cameraStatus == .authorized
    }
    
    /// Checks if all required permissions are granted
    var hasAllPermissions: Bool {
        return hasPhotoLibraryAccess && hasMicrophoneAccess && hasCameraAccess
    }
    
    // MARK: - Permission Requests
    
    /// Requests photo library permission
    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        await MainActor.run {
            self.photoLibraryStatus = status
        }
    }
    
    /// Requests microphone permission
    func requestMicrophonePermission() async {
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        await MainActor.run {
            self.microphoneStatus = granted ? .granted : .denied
        }
    }
    
    /// Requests camera permission
    func requestCameraPermission() async {
        let status = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            self.cameraStatus = status ? .authorized : .denied
        }
    }
    
    /// Requests all permissions needed for the app
    func requestAllPermissions() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.requestPhotoLibraryPermission()
            }
            group.addTask {
                await self.requestMicrophonePermission()
            }
            group.addTask {
                await self.requestCameraPermission()
            }
        }
    }
    
    // MARK: - Permission Messages
    
    /// Shows permission alert for photo library
    func showPhotoLibraryPermissionAlert() {
        permissionAlertMessage = "Photo access is required to add photos to your journal entries. Please enable photo access in Settings."
        showingPermissionAlert = true
    }
    
    /// Shows permission alert for microphone
    func showMicrophonePermissionAlert() {
        permissionAlertMessage = "Microphone access is required to record audio for your journal entries. Please enable microphone access in Settings."
        showingPermissionAlert = true
    }
    
    /// Shows permission alert for camera
    func showCameraPermissionAlert() {
        permissionAlertMessage = "Camera access is required to take photos for your journal entries. Please enable camera access in Settings."
        showingPermissionAlert = true
    }
    
    /// Shows permission alert for all permissions
    func showAllPermissionsAlert() {
        permissionAlertMessage = "Photo, microphone, and camera access are required to create journal entries. Please enable all permissions in Settings."
        showingPermissionAlert = true
    }
    
    // MARK: - Permission Status Messages
    
    /// Gets user-friendly message for photo library status
    var photoLibraryStatusMessage: String {
        switch photoLibraryStatus {
        case .authorized, .limited:
            return "Photo access granted"
        case .denied:
            return "Photo access denied"
        case .restricted:
            return "Photo access restricted"
        case .notDetermined:
            return "Photo access not requested"
        @unknown default:
            return "Photo access unknown"
        }
    }
    
    /// Gets user-friendly message for microphone status
    var microphoneStatusMessage: String {
        switch microphoneStatus {
        case .granted:
            return "Microphone access granted"
        case .denied:
            return "Microphone access denied"
        case .undetermined:
            return "Microphone access not requested"
        @unknown default:
            return "Microphone access unknown"
        }
    }
    
    /// Gets user-friendly message for camera status
    var cameraStatusMessage: String {
        switch cameraStatus {
        case .authorized:
            return "Camera access granted"
        case .denied:
            return "Camera access denied"
        case .restricted:
            return "Camera access restricted"
        case .notDetermined:
            return "Camera access not requested"
        @unknown default:
            return "Camera access unknown"
        }
    }
    
    // MARK: - Settings Navigation
    
    /// Opens app settings
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Permission Validation
    
    /// Validates photo library permission before operation
    func validatePhotoLibraryPermission() -> Bool {
        checkCurrentPermissions()
        if !hasPhotoLibraryAccess {
            showPhotoLibraryPermissionAlert()
            return false
        }
        return true
    }
    
    /// Validates microphone permission before operation
    func validateMicrophonePermission() -> Bool {
        checkCurrentPermissions()
        if !hasMicrophoneAccess {
            showMicrophonePermissionAlert()
            return false
        }
        return true
    }
    
    /// Validates camera permission before operation
    func validateCameraPermission() -> Bool {
        checkCurrentPermissions()
        if !hasCameraAccess {
            showCameraPermissionAlert()
            return false
        }
        return true
    }
    
    /// Validates all permissions before operation
    func validateAllPermissions() -> Bool {
        checkCurrentPermissions()
        if !hasAllPermissions {
            showAllPermissionsAlert()
            return false
        }
        return true
    }
}
