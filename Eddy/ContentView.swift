import SwiftUI
import AVFoundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let isMine: Bool
    let audioFileURL: URL?
}

struct ContentView: View {
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecording = false
    @State private var audioFileURL: URL?
    @State private var messages: [ChatMessage] = []
    
    var body: some View {
        VStack {
            List(messages) { message in
                HStack {
                    if message.isMine {
                        Spacer()
                        AudioMessageView(audioFileURL: message.audioFileURL)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    } else {
                        AudioMessageView(audioFileURL: nil, isTextToSpeech: true)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        Spacer()
                    }
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
            }
            .padding()
        }
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
            let newMessage = ChatMessage(isMine: true, audioFileURL: url)
            messages.append(newMessage)
            audioFileURL = nil
        }
        
        // Simulate receiving a "Hello, World!" text-to-speech message from the other person
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let textToSpeechMessage = ChatMessage(isMine: false, audioFileURL: nil)
            messages.append(textToSpeechMessage)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
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
    }


    
    func playAudio() {
        if isTextToSpeech {
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
