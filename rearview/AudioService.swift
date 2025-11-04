import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var audioPower: Float = 0.0
    @Published var isAppending = false
    private var timer: Timer?
    private var existingAudioURL: URL?
    
    deinit {
        stopRecording()
    }

    func startRecording() {
        startRecording(appendTo: nil)
    }
    
    func startAppending(to existingURL: URL) {
        existingAudioURL = existingURL
        isAppending = true
        startRecording(appendTo: existingURL)
    }
    
    private func startRecording(appendTo existingURL: URL?) {
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentPath.appendingPathComponent("\(UUID().uuidString).\(AppConstants.Audio.fileExtension)")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: AppConstants.Audio.sampleRate,
                AVNumberOfChannelsKey: AppConstants.Audio.numberOfChannels,
                // FIX: Changed from .high to .medium to reduce file size and upload time.
                AVEncoderAudioQualityKey: AppConstants.Audio.quality.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.audioRecorder?.updateMeters()
                let power = self?.audioRecorder?.averagePower(forChannel: 0) ?? -160.0
                // Convert decibels to a linear scale (0-1)
                self?.audioPower = self?.dbToLinear(power) ?? 0.0
            }

        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            // Call the synchronous version of stopRecording
            _ = stopRecording()
        }
    }

    // Corrected: This function now returns a URL? and does not use a completion handler.
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        let newRecordingURL = audioRecorder?.url
        audioRecorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
        audioPower = 0.0
        
        // If we were appending, combine the audio files
        if isAppending, let existingURL = existingAudioURL, let newURL = newRecordingURL {
            let combinedURL = combineAudioFiles(existing: existingURL, new: newURL)
            isAppending = false
            existingAudioURL = nil
            return combinedURL
        }
        
        isAppending = false
        existingAudioURL = nil
        return newRecordingURL
    }
    
    private func combineAudioFiles(existing: URL, new: URL) -> URL? {
        do {
            // Create a new combined audio file
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let combinedFilename = documentPath.appendingPathComponent("\(UUID().uuidString).\(AppConstants.Audio.fileExtension)")
            
            // Create an AVMutableComposition
            let composition = AVMutableComposition()
            guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                return new
            }
            
            // Add existing audio
            let existingAsset = AVAsset(url: existing)
            guard let existingAudioTrack = existingAsset.tracks(withMediaType: .audio).first else {
                print("No audio track found in existing file")
                return new
            }
            let existingTimeRange = CMTimeRange(start: .zero, duration: existingAsset.duration)
            try audioTrack.insertTimeRange(existingTimeRange, of: existingAudioTrack, at: .zero)
            
            // Add new audio after existing
            let newAsset = AVAsset(url: new)
            guard let newAudioTrack = newAsset.tracks(withMediaType: .audio).first else {
                print("No audio track found in new file")
                return existing
            }
            let newTimeRange = CMTimeRange(start: .zero, duration: newAsset.duration)
            try audioTrack.insertTimeRange(newTimeRange, of: newAudioTrack, at: existingAsset.duration)
            
            // Export the combined audio
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
                return new
            }
            
            exportSession.outputURL = combinedFilename
            exportSession.outputFileType = .m4a
            
            let semaphore = DispatchSemaphore(value: 0)
            var result: URL? = new
            
            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    result = combinedFilename
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            // Clean up temporary files
            try? FileManager.default.removeItem(at: new)
            
            return result
        } catch {
            print("Failed to combine audio files: \(error)")
            return new
        }
    }
    
    private func dbToLinear(_ db: Float) -> Float {
        return pow(10, db / 20)
    }
}

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var audioPower: Float = 0.0
    private var timer: Timer?
    
    deinit {
        stopPlayback()
    }
    
    // --- Start of MODIFIED FUNCTION ---
    func startPlayback(url: URL) {
        // Check if the URL is remote (http/https)
        if url.scheme?.starts(with: "http") == true {
            // It's a remote URL, so we need to download it first
            let downloadTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
                guard let data = data, error == nil else {
                    print("Failed to download audio file: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Save the downloaded data to a temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(AppConstants.Audio.fileExtension)
                
                do {
                    try data.write(to: tempURL)
                    // Now, play from the local temporary file on the main thread
                    DispatchQueue.main.async {
                        self?.play(url: tempURL)
                    }
                } catch {
                    print("Failed to write temporary audio file: \(error)")
                }
            }
            downloadTask.resume()
        } else {
            // It's a local file URL, play it directly
            play(url: url)
        }
    }
    
    // Extracted the core playback logic into its own function
    private func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.isMeteringEnabled = true
            audioPlayer?.play()
            isPlaying = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.audioPlayer?.updateMeters()
                let power = self?.audioPlayer?.averagePower(forChannel: 0) ?? -160.0
                self?.audioPower = self?.dbToLinear(power) ?? 0.0
            }
        } catch {
            print("Failed to start playback: \(error.localizedDescription)")
            stopPlayback()
        }
    }
    // --- End of MODIFIED FUNCTION ---

    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        timer?.invalidate()
        timer = nil
        audioPower = 0.0
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayback()
    }
    
    private func dbToLinear(_ db: Float) -> Float {
        return pow(10, db / 20)
    }
}
