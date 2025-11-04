import SwiftUI

struct EditAccountView: View {
    @EnvironmentObject var authManager: FirebaseManager
    @EnvironmentObject var guestModeManager: GuestModeManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var newEmail: String = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingCreateAccount = false
    
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?

    var body: some View {
        ZStack {
            let logoBlue = Color(red: 67/255, green: 133/255, blue: 204/255)
            
            LinearGradient(gradient: Gradient(colors: [logoBlue.opacity(0.1), .black]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                HStack {
                    Text("Account")
                        .font(.largeTitle).fontWeight(.bold)
                    Spacer()
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showingImagePicker = true
                }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let image = getCurrentProfileImage() {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray)
                        }
                        
                        // Use the reusable EditIcon view
                        EditIcon()
                            .offset(x: -5, y: -5)
                    }
                }
                
                if guestModeManager.isGuestMode {
                    // Guest mode content
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Guest Mode")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("Your data is stored locally and won't sync across devices. Create an account to sync your data and access it from anywhere.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            showingCreateAccount = true
                        }) {
                            Text("Create Account")
                        }
                        .buttonStyle(GradientButtonStyle())
                        
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            // Sign out any authenticated user first
                            authManager.signOut()
                            // Then disable guest mode
                            guestModeManager.disableGuestMode()
                            // Dismiss the view - this will take user to sign-in screen
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Sign In Instead")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                } else {
                    // Authenticated user content
                    VStack(alignment: .leading) {
                        Text("Update Email")
                            .font(.headline)
                        
                        TextField("New Email", text: $newEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            updateEmail()
                        }) {
                            Text("Save Email")
                        }
                        .buttonStyle(GradientButtonStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Actions")
                            .font(.headline)

                        actionButton(title: "Send Password Reset", action: sendPasswordReset)
                        actionButton(title: "Sign Out", action: signOut)
                        
                        Button(action: {
                            HapticManager.shared.play(.warning)
                            showingDeleteConfirmation = true
                        }) {
                             Text("Delete Account")
                                 .fontWeight(.bold)
                                 .foregroundColor(.red)
                                 .frame(maxWidth: .infinity)
                                 .padding()
                                 .background(Color.white.opacity(0.1))
                                 .cornerRadius(10)
                         }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            self.newEmail = authManager.userSession?.email ?? ""
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Are you sure?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                HapticManager.shared.play(.error)
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all of your data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingCreateAccount) {
            AuthenticationView(initialSignUpState: true)
        }
        .onChange(of: selectedImage) { image in
            guard let image = image else { return }
            HapticManager.shared.play(.success)
            
            if guestModeManager.isGuestMode {
                guestModeManager.saveGuestProfileImage(image)
            } else if let uid = authManager.userSession?.uid {
                authManager.uploadProfileImage(image, for: uid)
            }
        }
    }
    
    private func getCurrentProfileImage() -> UIImage? {
        if guestModeManager.isGuestMode {
            return guestModeManager.guestProfileImage
        } else {
            return authManager.profileImage
        }
    }
    
    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
        }
    }
    
    private func updateEmail() {
        authManager.updateEmail(to: newEmail) { error in
            if let error = error {
                HapticManager.shared.play(.error)
                self.alertTitle = "Error"
                self.alertMessage = error.localizedDescription
            } else {
                HapticManager.shared.play(.success)
                self.alertTitle = "Success"
                self.alertMessage = "Your email has been updated."
            }
            self.showingAlert = true
        }
    }
    
    private func sendPasswordReset() {
        authManager.sendPasswordReset { error in
            if let error = error {
                HapticManager.shared.play(.error)
                self.alertTitle = "Error"
                self.alertMessage = error.localizedDescription
                self.showingAlert = true
            } else {
                HapticManager.shared.play(.success)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func signOut() {
        authManager.signOut()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteAccount() {
        authManager.deleteAccount { error in
            if let error = error {
                HapticManager.shared.play(.error)
                self.alertTitle = "Error"
                self.alertMessage = error.localizedDescription
                self.showingAlert = true
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

