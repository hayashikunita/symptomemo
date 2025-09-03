import Foundation
import SwiftUI
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
        // Ensure permissions granted
        guard isAuthorized else { throw NSError(domain: "dictation", code: 0, userInfo: [NSLocalizedDescriptionKey: "Permissions not granted"]) }
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
    @State private var showPermissionAlert = false

    var body: some View {
    Button {
            if helper.isRecording {
                helper.stop(); onResult(bufferText); bufferText = ""
            } else {
                if helper.isAuthorized {
                    try? helper.start()
                } else {
                    Task { @MainActor in
                        await helper.requestPermissions()
                        if helper.isAuthorized { try? helper.start() }
                        else { showPermissionAlert = true }
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(helper.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 56, height: 56)
                Image(systemName: helper.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(helper.isRecording ? 0.7 : 0.35), lineWidth: helper.isRecording ? 3 : 2)
                .frame(width: 62, height: 62)
        )
        .shadow(color: Color.black.opacity(helper.isRecording ? 0.28 : 0.18), radius: helper.isRecording ? 10 : 8, x: 0, y: helper.isRecording ? 6 : 4)
    .task {
            if !helper.isAuthorized { await helper.requestPermissions() }
        }
    .onChange(of: helper.transcript) { _, newValue in bufferText = newValue }
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            helper.stop()
        }
        .alert("マイク/音声認識の許可が必要です", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("設定 > プライバシーとセキュリティ > マイク/音声認識 で許可してください。")
        }
    }
}
