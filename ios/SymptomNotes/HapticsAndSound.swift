import Foundation
import AVFoundation
import UIKit

enum HapticType { case light, success, error }

struct Feedback {
    static func haptic(_ type: HapticType) {
        switch type {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    static func clickSound() {
        // 控えめなシステムサウンド（トック音）
        AudioServicesPlaySystemSound(1104)
    }
}
