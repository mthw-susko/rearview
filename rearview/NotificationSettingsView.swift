//
//  NotificationSettingsView.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import SwiftUI

/// Settings view for managing notification preferences
struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var authManager: FirebaseManager
    @EnvironmentObject var viewModel: CalendarViewModel
    
    @State private var showingPermissionAlert = false
    
    private let logoBlue = AppConstants.Colors.logoBlue
    private let logoTeal = AppConstants.Colors.logoTeal
    
    // MARK: - Responsive Layout
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.bounds.width > 768
    }
    
    private var responsiveMaxWidth: CGFloat {
        isIPad ? 500 : .infinity
    }
    
    private var responsiveHorizontalPadding: CGFloat {
        isIPad ? 60 : 20
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        logoBlue.opacity(0.1),
                        logoTeal.opacity(0.05),
                        Color.black
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title section
                        VStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 50))
                                .foregroundColor(logoBlue)
                            
                            Text("Notification Settings")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Get reminded to add photos and audio to your journal entries")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        VStack(spacing: 20) {
                            // Permission Status Card
                            permissionStatusCard
                            
                            // Reminder Time Card
                            reminderTimeCard
                            
                            // Current Status Card
                            currentStatusCard
                        }
                        .padding(.horizontal, responsiveHorizontalPadding)
                        .frame(maxWidth: responsiveMaxWidth)
                        
                        Spacer(minLength: 50)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Force single column on iPad
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive journal reminders.")
        }
    }
    
    // MARK: - Card Views
    
    private var permissionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(notificationManager.isAuthorized ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification Status")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            if !notificationManager.isAuthorized {
                Button("Enable Notifications") {
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(
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
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var reminderTimeCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(logoBlue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reminder Time")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("When to remind you about journal entries")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            DatePicker("", selection: Binding(
                get: {
                    let calendar = Calendar.current
                    let hour = notificationManager.eveningReminderTime.hour ?? 20
                    let minute = notificationManager.eveningReminderTime.minute ?? 0
                    return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
                },
                set: { newValue in
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.hour, .minute], from: newValue)
                    notificationManager.updateEveningReminderTime(components)
                }
            ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .colorScheme(.dark)
        }
        .padding(20)
        .background(
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
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var currentStatusCard: some View {
        let today = Date()
        let entry = viewModel.entryFor(date: today)
        let isCompleted = entry?.isCompleted ?? false
        let hasContent = entry?.hasContent ?? false
        
        return VStack(spacing: 16) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : hasContent ? "exclamationmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : hasContent ? .orange : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Journal")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(isCompleted ? "Entry completed" : hasContent ? "Entry in progress" : "No entry yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            if !isCompleted && notificationManager.isAuthorized {
                if hasContent {
                    Text("Add both photos and audio to complete your entry")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                } else {
                    Text("You'll receive a reminder at \(formatTime(notificationManager.eveningReminderTime))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(20)
        .background(
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
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 20
        let minute = components.minute ?? 0
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppConstants.Colors.logoBlue, AppConstants.Colors.logoTeal]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(NotificationManager.shared)
        .environmentObject(FirebaseManager())
        .environmentObject(CalendarViewModel())
}

