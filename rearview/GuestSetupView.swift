//
//  GuestSetupView.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import SwiftUI
import PhotosUI

struct GuestSetupView: View {
    @EnvironmentObject var guestModeManager: GuestModeManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.presentationMode) var presentationMode
    @Binding var showingWelcome: Bool
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var showingPermissionAlert = false
    
    private let logoBlue = AppConstants.Colors.logoBlue
    private let logoTeal = AppConstants.Colors.logoTeal
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [logoBlue.opacity(0.3), .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Header
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 80))
                            .foregroundColor(logoBlue)
                        
                        Text("Continue as Guest")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Your data will be stored locally and won't sync across devices. You can create an account later to sync your data.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Profile Image Section
                    VStack(spacing: 20) {
                        Text("Choose a Profile Image (Optional)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            Task {
                                await requestPhotoPermissionAndShowPicker()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                if let profileImage = guestModeManager.guestProfileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                        Text("Add Photo")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                        .overlay(
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Color.clear
                            }
                            .opacity(permissionManager.hasPhotoLibraryAccess ? 1 : 0)
                        )
                        
                        if guestModeManager.guestProfileImage != nil {
                            Button("Remove Photo") {
                                guestModeManager.clearGuestProfileImage()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button("Continue as Guest") {
                            Task {
                                // Request permissions before enabling guest mode
                                await permissionManager.requestAllPermissions()
                                
                                // Request notification permissions for guest users
                                await notificationManager.requestAuthorization()
                                
                                guestModeManager.enableGuestMode()
                                showingWelcome = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        
                        Button("Create Account Instead") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: Binding(
                get: { nil },
                set: { newImage in
                    if let newImage = newImage {
                        guestModeManager.saveGuestProfileImage(newImage)
                    }
                }
            ))
        }
        .onChange(of: selectedPhotoItem) { newItem in
            if let newItem = newItem {
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            guestModeManager.saveGuestProfileImage(image)
                        }
                    }
                }
            }
        }
        .alert("Photo Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                permissionManager.openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable photo access to choose a profile image.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestPhotoPermissionAndShowPicker() async {
        // First check if we already have permission
        if permissionManager.hasPhotoLibraryAccess {
            showingImagePicker = true
            return
        }
        
        // Request permission
        await permissionManager.requestPhotoLibraryPermission()
        
        // Check if permission was granted
        if permissionManager.hasPhotoLibraryAccess {
            showingImagePicker = true
        } else {
            // Show alert if permission was denied
            showingPermissionAlert = true
        }
    }
}

#Preview {
    GuestSetupView(showingWelcome: .constant(true))
        .environmentObject(GuestModeManager.shared)
        .environmentObject(PermissionManager.shared)
        .environmentObject(NotificationManager.shared)
}
