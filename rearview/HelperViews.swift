//
//  HelperViews.swift
//  rearview
//
//  Created by Matthew Susko on 2025-09-27.
//

import SwiftUI

// MARK: - Reusable Views

struct AsyncJournalImage: View {
    let journalImage: JournalImage
    var isThumbnail: Bool = false
    
    @State private var image: Image?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var currentImageId: String?
    @EnvironmentObject var viewModel: CalendarViewModel

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            if hasError {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.red)
                    if !isThumbnail {
                        Text("Failed to load image")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } else if let image = image {
                ClippedImageView(image: image, isThumbnail: isThumbnail)
            } else if isLoading {
                ProgressView()
            } else {
                // Initial state
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear(perform: loadImage)
        .onChange(of: journalImage, perform: { _ in loadImage() })
        .accessibilityLabel(hasError ? "Failed to load image" : (image != nil ? "Journal image" : "Loading image"))
        .accessibilityHint(hasError ? "Image failed to load" : (image != nil ? "Double tap to view full size" : "Image is loading"))
    }
    
    private func loadImage() {
        // Store the current image ID to prevent race conditions
        let imageId = journalImage.id
        
        // Reset all states immediately to prevent overlap
        self.image = nil
        self.hasError = false
        self.isLoading = false
        self.currentImageId = imageId
        
        // If it's a temporary local image, display it immediately
        if let localUIImage = journalImage.image {
            self.image = Image(uiImage: localUIImage)
            return
        }
        
        // If it's a remote URL, proceed to load it
        guard let urlString = journalImage.url else { 
            self.hasError = true
            return 
        }
        
        self.isLoading = true
        
        // Load the image from the URL
        viewModel.loadImage(from: urlString) { loadedImage in
            DispatchQueue.main.async {
                // Double-check that this is still the current image to prevent race conditions
                guard self.currentImageId == imageId else { return }
                
                self.isLoading = false
                if let loadedImage = loadedImage {
                    self.image = Image(uiImage: loadedImage)
                } else {
                    self.hasError = true
                }
            }
        }
    }
}

struct ClippedImageView: View {
    let image: Image
    let isThumbnail: Bool
    
    var body: some View {
        GeometryReader { geometry in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
        }
    }
}

struct SoundWaveView: View {
    var amplitude: CGFloat
    @State private var animationOffset: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<21, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: 2.5,
                        height: calculateBarHeight(for: index, amplitude: amplitude)
                    )
                    .scaleEffect(y: isAnimating ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.15)
                        .delay(Double(index) * 0.01),
                        value: amplitude
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: amplitude) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                isAnimating.toggle()
            }
        }
    }
    
    private func calculateBarHeight(for index: Int, amplitude: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 45
        let centerIndex = 10 // Middle of 21 bars
        
        // Create a wave pattern that's higher in the center
        let distanceFromCenter = abs(index - centerIndex)
        let centerFactor = max(0.3, 1 - CGFloat(distanceFromCenter) / 10)
        
        // Add some randomness for natural look
        let randomFactor = 0.8 + CGFloat.random(in: 0...0.4)
        
        // Create a more dynamic wave pattern
        let wavePattern = sin(Double(index) * 0.3 + animationOffset) * 0.3 + 0.7
        
        let height = baseHeight + (maxHeight - baseHeight) * amplitude * centerFactor * randomFactor * CGFloat(wavePattern)
        return max(baseHeight, min(maxHeight, height))
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.08)) {
                animationOffset += 0.2
            }
        }
    }
}

struct ModernSoundWaveView: View {
    var amplitude: CGFloat
    @State private var animationPhase: CGFloat = 0
    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 30) // Optimal number of bars for width
    
    var body: some View {
        HStack(spacing: 2) { // Wider spacing for better visual separation
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.3)
                            ]),
                            center: .top,
                            startRadius: 0,
                            endRadius: 6
                        )
                    )
                    .frame(
                        width: 4, // Wider bars for better visibility
                        height: bars[index] * 50 + 6 // Increased max height
                    )
                    .scaleEffect(y: 1.0 + sin(animationPhase + Double(index) * 0.3) * 0.15)
                    .animation(
                        .easeInOut(duration: 0.08) // Faster animation
                        .delay(Double(index) * 0.01), // Reduced delay
                        value: bars[index]
                    )
            }
        }
        .frame(maxWidth: .infinity) // Take up full available width
        .onAppear {
            startContinuousAnimation()
        }
        .onChange(of: amplitude) { newAmplitude in
            updateBars(amplitude: newAmplitude)
        }
    }
    
    private func updateBars(amplitude: CGFloat) {
        // Increased sensitivity - multiply amplitude by 2.5 for more responsiveness
        let sensitiveAmplitude = min(1.0, amplitude * 2.5)
        
        for i in 0..<bars.count {
            let centerIndex = bars.count / 2
            let distanceFromCenter = abs(i - centerIndex)
            let centerFactor = max(0.1, 1 - CGFloat(distanceFromCenter) / CGFloat(centerIndex))
            
            // More responsive with higher random variation
            let randomFactor = 0.5 + CGFloat.random(in: 0...1.0)
            let wavePattern = sin(Double(i) * 0.4 + animationPhase) * 0.2 + 0.8
            
            let newValue = sensitiveAmplitude * centerFactor * randomFactor * CGFloat(wavePattern)
            bars[i] = max(0.05, min(1.0, newValue)) // Lower minimum for more sensitivity
        }
    }
    
    private func startContinuousAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.03)) {
                animationPhase += 0.4 // Faster animation
            }
        }
    }
}

// A reusable view for the small edit icon (e.g., on profile pictures).
struct EditIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 30, height: 30)
            
            Image(systemName: "pencil")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
    }
}


// MARK: - Reusable Styles

struct GradientButtonStyle: ButtonStyle {
    // Define colors from the logo for use in the button
    private let logoBlue = Color(red: 67/255, green: 133/255, blue: 204/255)
    private let logoTeal = Color(red: 92/255, green: 184/255, blue: 178/255)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(gradient: Gradient(colors: [logoBlue, logoTeal]), startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .frame(width: AppConstants.Dimensions.buttonSize, height: AppConstants.Dimensions.buttonSize)
            .background(.white)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.defaultDuration), value: configuration.isPressed)
    }
}

struct TransparentCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
    }
}

