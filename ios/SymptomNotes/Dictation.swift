import Foundation
import Speech
import AVFoundation

@MainActor
final class DictationHelper: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isRecording = false
    @Published var transcript: String = ""

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current)

    func requestPermissions() async {
        let mic: Bool = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        isAuthorized = mic && (speech == .authorized)
    }

    func start() throws {
        guard !isRecording else { return }
        isRecording = true

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { throw NSError(domain: "dictation", code: 1) }
        request.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
                if result.isFinal { self.stop() }
            }
            if error != nil { self.stop() }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

struct DictationButton: View {
    @ObservedObject var helper: DictationHelper
    var onResult: (String) -> Void

    @State private var bufferText: String = ""

    var body: some View {
        Button {
            if helper.isRecording { helper.stop(); onResult(bufferText); bufferText = "" }
            else { try? helper.start() }
        } label: {
            Label(helper.isRecording ? "停止" : "音声入力", systemImage: helper.isRecording ? "stop.circle.fill" : "mic.circle")
        }
        .buttonStyle(.borderedProminent)
    .task {
            if !helper.isAuthorized { await helper.requestPermissions() }
        }
    .onChange(of: helper.transcript) { bufferText = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .AVAudioSessionInterruption)) { _ in
            helper.stop()
        }
    }
}
