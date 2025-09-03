import Foundation

enum DeveloperOverrides {
    static var forcePremium: Bool {
        get {
#if DEBUG
            return UserDefaults.standard.bool(forKey: "dev.forcePremium")
#else
            return false
#endif
        }
        set {
#if DEBUG
            UserDefaults.standard.set(newValue, forKey: "dev.forcePremium")
#endif
        }
    }
}
