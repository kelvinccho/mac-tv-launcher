import AVFoundation
import Speech
import Combine

@MainActor
final class VoiceController: ObservableObject {
    @Published var listening = false
    @Published var message = ""
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var silence: Task<Void, Never>?
    private var installedTap = false
    private var generation = UUID()

    func toggle(onCommand: @escaping (String) -> Void) {
        if listening { cancel(); return }
        listening = true
        message = "Requesting microphone and speech access…"
        let session = UUID()
        generation = session
        Task {
            let speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard generation == session else { return }
            guard speech == .authorized else {
                cancel(message: "Allow Speech Recognition in System Settings → Privacy & Security, then try again.")
                return
            }
            let microphone = await AVCaptureDevice.requestAccess(for: .audio)
            guard generation == session else { return }
            guard microphone else {
                cancel(message: "Allow Microphone in System Settings → Privacy & Security, then try again.")
                return
            }
            start(session: session, onCommand: onCommand)
        }
    }

    private func start(session: UUID, onCommand: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            cancel(message: "Speech recognition is unavailable. Use the arrow keys and Return.")
            return
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cancel(message: "No microphone found. Connect one, or use the keyboard.")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = ["YouTube", "Netflix", "TeeVee"]
        self.request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        installedTap = true
        do { try engine.start() } catch {
            cancel(message: "Could not start the microphone: \(error.localizedDescription)")
            return
        }
        message = "Listening… Say ‘open YouTube’, ‘Netflix’ or ‘TeeVee’."
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == session else { return }
                if let transcript {
                    self.message = "Heard: \(transcript)"
                    self.silence?.cancel()
                    if isFinal {
                        self.cancel(message: "Heard: \(transcript)")
                        onCommand(transcript)
                    } else {
                        self.silence = Task { [weak self] in
                            do { try await Task.sleep(nanoseconds: 1_600_000_000) } catch { return }
                            guard let self, self.generation == session else { return }
                            self.cancel(message: "Heard: \(transcript)")
                            onCommand(transcript)
                        }
                    }
                } else if failed {
                    self.cancel(message: "Speech recognition failed. Try again or use the keyboard.")
                }
            }
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 10_000_000_000) } catch { return }
            guard let self, self.generation == session else { return }
            self.cancel(message: "No command heard. Press ⌘⇧Space to try again.")
        }
    }

    func cancel(message: String = "Voice control stopped.") {
        generation = UUID()
        timeout?.cancel()
        silence?.cancel()
        engine.stop()
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        listening = false
        self.message = message
    }
}
