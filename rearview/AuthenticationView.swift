import SwiftUI
import PhotosUI

// A simple image picker for selecting a single photo (e.g., for a profile picture).
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}


struct AuthenticationView: View {
    @EnvironmentObject var authManager: FirebaseManager
    @EnvironmentObject var guestModeManager: GuestModeManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var isSignUpActive: Bool
    @State private var pulseScale = 1.0
    @State private var pulseOpacity = 0.1
    
    init(initialSignUpState: Bool = false) {
        _isSignUpActive = State(initialValue: initialSignUpState)
    }
    
    private func enableGuestMode() {
        Task {
            // Request permissions before enabling guest mode
            await permissionManager.requestAllPermissions()
            
            // Request notification permissions for guest users
            await notificationManager.requestAuthorization()
            
            guestModeManager.enableGuestMode()
        }
    }

    var body: some View {
        ZStack {
            // Define colors from the logo for use in this view
            let logoBlue = AppConstants.Colors.logoBlue
            
            LinearGradient(gradient: Gradient(colors: [logoBlue.opacity(0.3), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                ZStack {
                    // Pulsing blue background effect
                    Circle()
                        .fill(logoBlue.opacity(pulseOpacity))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)
                        .blur(radius: 8)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseOpacity)
                    
                    // Logo image
                    Image("just_goggles")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 250)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 10)
                
                Text(isSignUpActive ? AppConstants.Strings.createAccount : AppConstants.Strings.welcomeBack)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(isSignUpActive ? AppConstants.Strings.signUpSubtitle : AppConstants.Strings.signInSubtitle)
                    .foregroundColor(.gray)
                    .padding(.top, 2)
                    .multilineTextAlignment(.center)

                if isSignUpActive {
                    SignUpView(authManager: authManager, isSignUpActive: $isSignUpActive)
                } else {
                    SignInView(authManager: authManager, isSignUpActive: $isSignUpActive, onGuestMode: enableGuestMode)
                }
                
                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Start the pulsing animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
                pulseOpacity = 0.4
            }
        }
    }
}

struct SignInView: View {
    @ObservedObject var authManager: FirebaseManager
    @Binding var isSignUpActive: Bool
    let onGuestMode: () -> Void
    
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
                .disabled(authManager.isSigningIn || authManager.isLoading)

            SecureField("Password", text: $password)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
                .disabled(authManager.isSigningIn || authManager.isLoading)

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                HapticManager.shared.impact(.medium)
                authManager.signIn(email: email, password: password)
            }) {
                HStack {
                    if authManager.isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(authManager.isSigningIn ? "Signing In..." : "Sign In")
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(authManager.isSigningIn || authManager.isLoading)
            
            Button(action: {
                HapticManager.shared.impact(.light)
                isSignUpActive = true
            }) {
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.gray)
                    Text("Sign Up")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .disabled(authManager.isSigningIn || authManager.isLoading)
            .opacity((authManager.isSigningIn || authManager.isLoading) ? 0.5 : 1.0)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .foregroundColor(.gray)
                    .font(.caption)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 10)
            
            // Continue as Guest button
            Button(action: {
                HapticManager.shared.impact(.medium)
                onGuestMode()
            }) {
                Text("Continue as Guest")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(authManager.isSigningIn || authManager.isLoading)
            .opacity((authManager.isSigningIn || authManager.isLoading) ? 0.5 : 1.0)
        }
        .padding(.top, 30)
    }
}

struct SignUpView: View {
    @ObservedObject var authManager: FirebaseManager
    @Binding var isSignUpActive: Bool
    @EnvironmentObject var permissionManager: PermissionManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var profileImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var termsAccepted = false
    @State private var showingPermissionAlert = false

    var body: some View {
        VStack(spacing: 20) {
            
            Button(action: {
                Task {
                    await requestPhotoPermissionAndShowPicker()
                }
            }) {
                ZStack(alignment: .bottomTrailing) {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 100, height: 100)
                    }
                    EditIcon()
                }
            }
            .disabled(authManager.isSigningUp || authManager.isLoading)
            .opacity((authManager.isSigningUp || authManager.isLoading) ? 0.5 : 1.0)
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
                .disabled(authManager.isSigningUp || authManager.isLoading)

            SecureField("Password", text: $password)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .foregroundColor(.white)
                .disabled(authManager.isSigningUp || authManager.isLoading)
            
            // FIX: Replaced the simple text with tappable links for Terms & Conditions and Privacy Policy.
            Toggle(isOn: $termsAccepted) {
                 HStack(spacing: 4) {
                     Text("I agree to the")
                     Link("Terms & Conditions", destination: URL(string: "https://doc-hosting.flycricket.io/rearview-terms-and-conditions/7891e804-b4d7-4c6a-a35d-d3f98260ded0/terms")!)
                     Text("and")
                     Link("Privacy Policy", destination: URL(string: "https://doc-hosting.flycricket.io/rearview-privacy-policy/be34945b-766e-4432-85c0-bcfe88eaffbf/privacy")!)
                 }
                 .font(.caption)
                 .foregroundColor(.gray)
                 .accentColor(.white)
            }
            .toggleStyle(CheckboxToggleStyle())
            .disabled(authManager.isSigningUp || authManager.isLoading)


            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                HapticManager.shared.impact(.medium)
                authManager.signUp(email: email, password: password, profileImage: profileImage)
            }) {
                HStack {
                    if authManager.isSigningUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(authManager.isSigningUp ? "Creating Account..." : "Sign Up")
                }
            }
            .buttonStyle(GradientButtonStyle())
            .disabled(!termsAccepted || authManager.isSigningUp || authManager.isLoading)
            .opacity((!termsAccepted || authManager.isSigningUp || authManager.isLoading) ? 0.5 : 1.0)

            Button(action: {
                HapticManager.shared.impact(.light)
                isSignUpActive = false
            }) {
                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.gray)
                    Text("Sign In")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .disabled(authManager.isSigningUp || authManager.isLoading)
            .opacity((authManager.isSigningUp || authManager.isLoading) ? 0.5 : 1.0)
            
        }
        .padding(.top, 30)
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $profileImage)
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
            isShowingImagePicker = true
            return
        }
        
        // Request permission
        await permissionManager.requestPhotoLibraryPermission()
        
        // Check if permission was granted
        if permissionManager.hasPhotoLibraryAccess {
            isShowingImagePicker = true
        } else {
            // Show alert if permission was denied
            showingPermissionAlert = true
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Button(action: {
                configuration.isOn.toggle()
                HapticManager.shared.impact(.light)
            }) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(configuration.isOn ? .white : .gray)
            }
            configuration.label
        }
    }
}

// Loading screen with pulsing logo
struct LoadingScreen: View {
    @State private var pulseScale = 1.0
    @State private var pulseOpacity = 0.1
    
    var body: some View {
        ZStack {
            // Define colors from the logo for use in this view
            let logoBlue = AppConstants.Colors.logoBlue
            
            LinearGradient(gradient: Gradient(colors: [logoBlue.opacity(0.3), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                ZStack {
                    // Pulsing blue background effect
                    Circle()
                        .fill(logoBlue.opacity(pulseOpacity))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)
                        .blur(radius: 8)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseOpacity)
                    
                    // Logo image
                    Image("just_goggles")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 250)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 10)
                
                Text("Loading...")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .opacity(0.8)
                
                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Start the pulsing animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
                pulseOpacity = 0.4
            }
        }
    }
}



