import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class FirebaseManager: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var errorMessage: String?
    @Published var profileImage: UIImage?
    @Published var isLoading = false
    @Published var isSigningUp = false
    @Published var isSigningIn = false
    @Published var isInitializing = true
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var minimumLoadingTime: TimeInterval = 1.5 // 1.5 seconds minimum loading time
    private var loadingStartTime: Date?
    
    init() {
        loadingStartTime = Date()
        listenToAuthState()
    }
    
    func listenToAuthState() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.userSession = user
                
                // Calculate elapsed time since loading started
                let elapsedTime = Date().timeIntervalSince(self?.loadingStartTime ?? Date())
                let remainingTime = max(0, (self?.minimumLoadingTime ?? 1.5) - elapsedTime)
                
                // Wait for minimum loading time before hiding loading screen
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                    self?.isInitializing = false
                }
                
                if user != nil {
                    print("Auth state changed - user signed in: \(user?.uid ?? "unknown")")
                    print("Current profile image state: \(self?.profileImage != nil)")
                    print("Is signing up: \(self?.isSigningUp ?? false)")
                    
                    // Don't fetch during signup process
                    if self?.isSigningUp == true {
                        print("Currently signing up, skipping profile image fetch")
                        return
                    }
                    
                    // Only fetch profile image if we don't already have one
                    if self?.profileImage == nil {
                        print("No profile image found, fetching from storage...")
                        self?.fetchProfileImage()
                    } else {
                        print("Profile image already exists, skipping fetch")
                    }
                } else {
                    print("Auth state changed - user signed out")
                    self?.profileImage = nil
                }
            }
        }
    }
    
    func signIn(email: String, password: String) {
        isSigningIn = true
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isSigningIn = false
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                self?.errorMessage = nil
                // Ensure profile image is fetched after successful sign in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.fetchProfileImage()
                }
            }
        }
    }
    
    func signUp(email: String, password: String, profileImage: UIImage?) {
        isSigningUp = true
        isLoading = true
        errorMessage = nil
        print("Starting signup process...")
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.isSigningUp = false
                    self?.isLoading = false
                    return
                }
                self?.errorMessage = nil
                
                guard let user = result?.user else { 
                    self?.isSigningUp = false
                    self?.isLoading = false
                    return 
                }
                
                if let image = profileImage {
                    print("Setting profile image immediately for user: \(user.uid)")
                    // Set the profile image immediately for UI display
                    DispatchQueue.main.async {
                        self?.profileImage = image
                        print("Profile image set in UI: \(self?.profileImage != nil)")
                        print("Profile image size: \(image.size)")
                        // Force UI update
                        self?.objectWillChange.send()
                    }
                    // Then upload it to storage
                    self?.uploadProfileImage(image, for: user.uid)
                } else {
                    print("No profile image provided during signup")
                }
                
                // Clear the loading states after a delay to allow upload to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.isSigningUp = false
                    self?.isLoading = false
                    print("Signup process completed, auth state listener can now fetch if needed")
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Storage
    
    func uploadProfileImage(_ image: UIImage, for uid: String) {
        let storageRef = Storage.storage().reference().child("profile_images").child("\(uid).jpg")
        
        guard let resizedImage = image.resized(to: AppConstants.Dimensions.profileImageMaxDimension),
              let imageData = resizedImage.jpegData(compressionQuality: AppConstants.Dimensions.profileImageCompressionQuality) else {
            print("Error resizing profile image")
            return
        }
        
        storageRef.putData(imageData, metadata: nil) { [weak self] _, error in
            if let error = error {
                print("Failed to upload profile image: \(error)")
                return
            }
            print("Profile image uploaded successfully")
            // No need to fetch since we already set the image immediately
            // The upload is just for persistence
        }
    }
    
    func fetchProfileImage() {
        guard let uid = userSession?.uid else { 
            print("No user ID available for fetching profile image")
            return 
        }
        let storageRef = Storage.storage().reference().child("profile_images/\(uid).jpg")
        
        print("Attempting to fetch profile image for user: \(uid)")
        storageRef.getData(maxSize: Int64(AppConstants.Audio.maxFileSize)) { data, error in
            if let error = error {
                print("Error downloading profile image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.profileImage = nil
                }
                return
            }
            
            if let data = data {
                print("Profile image data downloaded successfully, size: \(data.count) bytes")
                DispatchQueue.main.async {
                    self.profileImage = UIImage(data: data)
                    print("Profile image set successfully: \(self.profileImage != nil)")
                }
            } else {
                print("No profile image data found")
                DispatchQueue.main.async {
                    self.profileImage = nil
                }
            }
        }
    }

    func updateEmail(to newEmail: String, completion: @escaping (Error?) -> Void) {
        userSession?.updateEmail(to: newEmail, completion: completion)
    }

    func sendPasswordReset(completion: @escaping (Error?) -> Void) {
        guard let email = userSession?.email else {
            completion(NSError(domain: "AppError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in."]))
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            if error == nil {
                self?.signOut()
            }
            completion(error)
        }
    }
    
    func deleteAccount(completion: @escaping (Error?) -> Void) {
        userSession?.delete(completion: completion)
    }
}
