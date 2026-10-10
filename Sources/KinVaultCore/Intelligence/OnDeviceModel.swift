import Foundation
import FoundationModels

/// Whether Apple's on-device Foundation Model can be used right now.
///
/// KinVault only ever uses `SystemLanguageModel` — the model that runs on this Mac.
/// It never uses Private Cloud Compute or any other server.
public enum OnDeviceModel {
    public enum Status: Equatable, Sendable {
        case ready
        case appleIntelligenceOff
        case downloading
        case unsupportedMac
        case unavailable

        public var isReady: Bool { self == .ready }

        public var title: String {
            switch self {
            case .ready: "Apple Intelligence on this Mac"
            case .appleIntelligenceOff: "Apple Intelligence is off"
            case .downloading: "Apple Intelligence is getting ready"
            case .unsupportedMac: "Apple Intelligence isn't supported here"
            case .unavailable: "Apple Intelligence is unavailable"
            }
        }

        public var detail: String {
            switch self {
            case .ready:
                "Documents are read and questions answered by the on-device model. Nothing is sent anywhere."
            case .appleIntelligenceOff:
                "Turn it on in System Settings › Apple Intelligence & Siri. Until then KinVault reads labels and dates with patterns."
            case .downloading:
                "macOS is still downloading the model. KinVault reads labels and dates with patterns until it's ready."
            case .unsupportedMac:
                "Apple Intelligence needs a Mac with Apple silicon. KinVault reads labels and dates with patterns instead."
            case .unavailable:
                "KinVault reads labels and dates with patterns instead."
            }
        }
    }

    /// Personal documents are full of names, numbers and dates; the permissive guardrails are
    /// intended for exactly this kind of transformation of the user's own text.
    public static var model: SystemLanguageModel {
        SystemLanguageModel(guardrails: .permissiveContentTransformations)
    }

    /// Greedy sampling: the same document always reads the same way.
    static var deterministic: GenerationOptions {
        #if compiler(>=6.4)
        GenerationOptions(samplingMode: .greedy)
        #else
        GenerationOptions(sampling: .greedy)
        #endif
    }

    public static var status: Status {
        switch SystemLanguageModel.default.availability {
        case .available: .ready
        case .unavailable(.appleIntelligenceNotEnabled): .appleIntelligenceOff
        case .unavailable(.modelNotReady): .downloading
        case .unavailable(.deviceNotEligible): .unsupportedMac
        case .unavailable: .unavailable
        }
    }
}
