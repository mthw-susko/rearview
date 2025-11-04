//
//  WelcomeView.swift
//  rearview
//
//  Created by Matthew Susko on 2025-01-27.
//

import SwiftUI

struct WelcomeView: View {
    @State private var currentPage = 0
    @Binding var showingWelcome: Bool
    @State private var showingGuestSetup = false
    var onGetStarted: (() -> Void)?
    
    private let logoBlue = AppConstants.Colors.logoBlue
    private let logoTeal = AppConstants.Colors.logoTeal
    
    private let pages = [
        OnboardingPage(
            title: "Welcome to rearview",
            subtitle: "Capture your daily memories",
            description: "Create a visual journal by adding photos and audio recordings to document your day.",
            imageName: "just_goggles",
            color: AppConstants.Colors.logoBlue,
            isLogo: true
        ),
        OnboardingPage(
            title: "Add Photos",
            subtitle: "Visual memories",
            description: "Upload multiple photos from your day to create a visual story of your experiences.",
            imageName: "photo.on.rectangle.angled",
            color: AppConstants.Colors.logoTeal,
            isLogo: false
        ),
        OnboardingPage(
            title: "Record Audio",
            subtitle: "Voice your thoughts",
            description: "Capture your thoughts and feelings with audio recordings to complement your photos.",
            imageName: "mic.fill",
            color: AppConstants.Colors.logoBlue,
            isLogo: false
        ),
        OnboardingPage(
            title: "Evening Reminders",
            subtitle: "Never miss a day",
            description: "Get gentle reminders in the evening to add content to your journal entry.",
            imageName: "bell.fill",
            color: AppConstants.Colors.logoTeal,
            isLogo: false
        ),
        OnboardingPage(
            title: "Ready to Start?",
            subtitle: "Create your account",
            description: "Sign up to begin documenting your daily memories and building your personal journal.",
            imageName: "person.badge.plus",
            color: AppConstants.Colors.logoBlue,
            isLogo: false
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient - matching authentication screens
            LinearGradient(
                gradient: Gradient(colors: [logoBlue.opacity(0.3), .black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom controls
                VStack(spacing: 24) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        if currentPage < pages.count - 1 {
                            // Skip button
                            Button("Skip") {
                                withAnimation {
                                    currentPage = pages.count - 1
                                }
                            }
                            .foregroundColor(.gray)
                            .font(.body)
                            
                            Spacer()
                            
                            // Next button
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        } else {
                            // Action buttons
                            VStack(spacing: 12) {
                                Button("Get Started") {
                                    onGetStarted?()
                                    showingWelcome = false
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .frame(maxWidth: .infinity)
                                
                                Button("Continue as Guest") {
                                    showingGuestSetup = true
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingGuestSetup) {
            GuestSetupView(showingWelcome: $showingWelcome)
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let color: Color
    let isLogo: Bool
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            ZStack {
                if page.isLogo {
                    // Logo display
                    Image(page.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .foregroundColor(.white)
                } else {
                    // System icon display
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [page.color, page.color.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: page.imageName)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(page.color)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}


#Preview {
    WelcomeView(showingWelcome: .constant(true)) {
        // Preview callback
    }
}
