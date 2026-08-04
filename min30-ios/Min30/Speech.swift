import Foundation
import Speech
import AVFoundation
import Observation

/// On-device Korean dictation. Walking around, talking is faster than typing —
/// this is the input path that matters when your hands aren't free.
@Observable
@MainActor
final class Dictation {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    func toggle(seed: String = "") {
        isRecording ? stop() : start(seed: seed)
    }

    func start(seed: String = "") {
        guard !isRecording else { return }
        errorMessage = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor in
                guard let self else { return }
                guard auth == .authorized else {
                    self.errorMessage = "설정에서 음성 인식 권한을 허용해 주세요"
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        guard granted else {
                            self.errorMessage = "설정에서 마이크 권한을 허용해 주세요"
                            return
                        }
                        self.beginSession(seed: seed)
                    }
                }
            }
        }
    }

    private func beginSession(seed: String) {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "지금은 음성 인식을 쓸 수 없어요"
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            // keeps audio on the device; also works with no network
            req.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request = req

            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            node.removeTap(onBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }

            engine.prepare()
            try engine.start()
            isRecording = true

            let prefix = seed.isEmpty ? "" : seed.trimmingCharacters(in: .whitespaces) + " "
            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = prefix + result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        self.stop()
                    }
                }
            }
        } catch {
            errorMessage = "마이크를 열 수 없어요"
            stop()
        }
    }

    func stop() {
        guard isRecording || engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        transcript = ""
        errorMessage = nil
    }
}
