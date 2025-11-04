//
//  CameraService.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import SwiftUI
import AVFoundation
import UIKit

/// Service for handling camera operations
@MainActor
class CameraService: NSObject, ObservableObject {
    static let shared = CameraService()
    
    @Published var isShowingCamera = false
    @Published var capturedImage: UIImage?
    @Published var isCapturing = false
    
    private var imagePickerController: UIImagePickerController?
    
    private override init() {
        super.init()
    }
    
    /// Presents the camera interface
    func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera not available on this device")
            return
        }
        
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = false
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        
        self.imagePickerController = picker
        self.isShowingCamera = true
    }
    
    /// Dismisses the camera interface
    func dismissCamera() {
        isShowingCamera = false
        imagePickerController = nil
        capturedImage = nil
    }
    
    /// Resets the captured image
    func resetCapturedImage() {
        capturedImage = nil
    }
}

// MARK: - UIImagePickerControllerDelegate

extension CameraService: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            self.capturedImage = image
            self.isCapturing = false
        }
        
        picker.dismiss(animated: true) {
            self.isShowingCamera = false
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.isCapturing = false
        picker.dismiss(animated: true) {
            self.isShowingCamera = false
        }
    }
}

// MARK: - Camera Sheet View

struct CameraSheetView: UIViewControllerRepresentable {
    let cameraService: CameraService
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = cameraService
        picker.allowsEditing = false
        picker.cameraDevice = .rear
        picker.cameraFlashMode = .auto
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
}
