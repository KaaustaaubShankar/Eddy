import SwiftUI
import AVFoundation

import Foundation

func fetchAudioFromAPI(completion: @escaping (URL?) -> Void) {
    guard let url = URL(string: "http://192.168.1.203:4000/get-audio") else {
        completion(nil)
        return
    }

    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Failed to fetch audio file: \(error)")
            completion(nil)
            return
        }
        
        guard let data = data, let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("received-\(UUID()).mp3") as URL? else {
            completion(nil)
            return
        }
        
        do {
            try data.write(to: tempURL)
            completion(tempURL)
        } catch {
            print("Failed to save audio file: \(error)")
            completion(nil)
        }
    }
    
    task.resume()
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let isMine: Bool
    let audioFileURL: URL?
    let timestamp: Date
}

struct ContentView: View {
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecording = false
    @State private var audioFileURL: URL?
    @State private var messages: [ChatMessage] = []
    @State private var isDarkMode = false // State variable for dark mode
    
    var body: some View {
        VStack {
            List(messages) { message in
                VStack(alignment: .leading) {
                    HStack {
                        if message.isMine {
                            Spacer()
                            AudioMessageView(audioFileURL: message.audioFileURL)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                                .padding(.trailing, 16) // Add more padding to the right side for "mine" messages
                                .padding(.leading, 50) // Add more padding to the left side for spacing
                        } else {
                            AudioMessageView(audioFileURL: message.audioFileURL, isTextToSpeech: false) // Pass the URL for remote audio
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .padding(.leading, 16) // Add more padding to the left side for "other" messages
                                .padding(.trailing, 50) // Add more padding to the right side for spacing
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8) // Add vertical padding between messages
                    
                    // Timestamp
                    Text(formattedTimestamp(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, message.isMine ? 50 : 16)
                        .padding(.trailing, message.isMine ? 16 : 50)
                }
            }
            .listStyle(PlainListStyle())
            
            HStack {
                Button(action: {
                    self.recordButtonTapped()
                }) {
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    self.sendMessage()
                }) {
                    Text("Send")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(audioFileURL == nil)
                
                Button(action: {
                    self.isDarkMode.toggle()
                }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        .preferredColorScheme(isDarkMode ? .dark : .light) // Apply the color scheme
    }
    
    // MARK: - Recording and Sending Messages
    func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioFileURL = getDocumentsDirectory().appendingPathComponent("recording-\(UUID()).m4a")
            audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
        } catch {
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
    }
    
    func sendMessage() {
        if let url = audioFileURL {
            let newMessage = ChatMessage(isMine: true, audioFileURL: url, timestamp: Date()) // Set timestamp to current date and time
            messages.append(newMessage)
            audioFileURL = nil
        }
        
        // Fetch audio from API for the "other" person
        fetchAudioFromAPI { audioURL in
            DispatchQueue.main.async {
                let textToSpeechMessage = ChatMessage(isMine: false, audioFileURL: audioURL, timestamp: Date()) // Set timestamp to current date and time
                messages.append(textToSpeechMessage)
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


struct AudioMessageView: View {
    var audioFileURL: URL?
    var isTextToSpeech: Bool = false
    
    @State private var isPlaying = false
    @State private var emojiOffset: CGFloat = 0.0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    @State private var audioDelegate: AudioPlayerDelegateWrapper? // Retain the delegate
    @State private var speechDelegate: SpeechSynthesizerDelegateWrapper? // Retain the speech delegate

    var body: some View {
        HStack {
            Image(systemName: "face.smiling")
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundColor(isPlaying ? .red : .primary) // Change color based on isPlaying
            
            Button(action: {
                self.playAudio()
            }) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .padding()
            }
            .disabled(audioFileURL == nil && !isTextToSpeech)
        }
        .padding() // Add padding inside the message bubble
    }
    
    func playAudio() {
        if isPlaying {
            stopAudio()
        } else if isTextToSpeech {
            playTextToSpeech()
        } else if let url = audioFileURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioDelegate = AudioPlayerDelegateWrapper { finished in
                    self.isPlaying = false
                }
                audioPlayer?.delegate = audioDelegate
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Playback failed")
            }
        }
    }
    
    func stopAudio() {
        if isTextToSpeech {
            speechSynthesizer?.stopSpeaking(at: .immediate)
            isPlaying = false
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
        }
    }
    
    func playTextToSpeech() {
        speechSynthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "Hello, World!")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechDelegate = SpeechSynthesizerDelegateWrapper {
            self.isPlaying = false
        }
        speechSynthesizer?.delegate = speechDelegate
        speechSynthesizer?.speak(utterance)
        isPlaying = true
    }
}


class AudioPlayerDelegateWrapper: NSObject, AVAudioPlayerDelegate {
    let onFinish: (Bool) -> Void
    
    init(onFinish: @escaping (Bool) -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish(flag)
    }
}

class SpeechSynthesizerDelegateWrapper: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
}
