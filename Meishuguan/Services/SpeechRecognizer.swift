import AVFoundation
import Speech
import Observation

@Observable
final class SpeechRecognizer {
    var transcript: String = ""
    var isRecording: Bool = false
    var lastError: String?

    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        return micOK
    }

    func startRecording() {
        guard !isRecording else { return }
        transcript = ""
        lastError = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    Task { @MainActor in
                        self.transcript = result.bestTranscription.formattedString
                    }
                }
                if let error {
                    Task { @MainActor in
                        self.lastError = error.localizedDescription
                    }
                }
            }
            isRecording = true
        } catch {
            lastError = error.localizedDescription
            isRecording = false
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
