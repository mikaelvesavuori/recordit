import Foundation
import AVFoundation

public enum RecordingFormat: String, CaseIterable, Identifiable, Sendable {
    case alac
    case aac

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .alac: return "ALAC (Lossless)"
        case .aac: return "AAC (Lossy)"
        }
    }

    public var fileExtension: String { "m4a" }

    public var avFileType: AVFileType { .m4a }

    public var isLossless: Bool {
        switch self {
        case .alac: return true
        case .aac: return false
        }
    }

    public func fileSettings(sampleRate: Double, channels: UInt32, quality: RecordingQuality) -> [String: Any] {
        switch self {
        case .alac:
            return [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: quality.aacBitRate,
                AVEncoderAudioQualityKey: quality.avAudioQuality.rawValue,
            ]
        }
    }
}

public enum RecordingQuality: String, CaseIterable, Identifiable, Sendable {
    case low, medium, high

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    public var aacBitRate: Int {
        switch self {
        case .low: return 128_000
        case .medium: return 192_000
        case .high: return 256_000
        }
    }

    public var avAudioQuality: AVAudioQuality {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}
