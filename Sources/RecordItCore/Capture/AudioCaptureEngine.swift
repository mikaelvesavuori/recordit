import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation

public final class AudioCaptureEngine: @unchecked Sendable {
    private var tapObjectID: AudioObjectID = kAudioObjectUnknown
    private var aggregateDeviceID: AudioObjectID = kAudioObjectUnknown
    private var ioProcID: AudioDeviceIOProcID?
    private let captureQueue = DispatchQueue(label: "com.recordit.capture", qos: .userInitiated)
    private let stateLock = NSLock()

    public var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    public var onLevelUpdate: ((Float) -> Void)?

    public private(set) var audioFormat: AVAudioFormat?

    public init() {}

    public func start(processObjectID: AudioObjectID) throws {
        let description = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var createdTapID = kAudioObjectUnknown
        let createStatus = AudioHardwareCreateProcessTap(description, &createdTapID)
        guard createStatus == noErr, createdTapID != kAudioObjectUnknown else {
            throw AudioCaptureError.tapCreationFailed(createStatus)
        }
        self.tapObjectID = createdTapID

        let tapUID = try getTapUID(tapObjectID)
        aggregateDeviceID = try createAggregateDevice(tapUID: tapUID)

        var streamFormat = try getStreamFormat(aggregateDeviceID)
        guard let format = AVAudioFormat(streamDescription: &streamFormat) else {
            throw AudioCaptureError.formatCreationFailed
        }
        self.audioFormat = format

        let status = AudioDeviceCreateIOProcIDWithBlock(
            &ioProcID,
            aggregateDeviceID,
            captureQueue
        ) { [weak self] _, inputData, _, _, _ in
            self?.handleAudioInput(inputData)
        }

        guard status == noErr else {
            throw AudioCaptureError.ioProcCreationFailed(status)
        }

        let startStatus = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard startStatus == noErr else {
            throw AudioCaptureError.deviceStartFailed(startStatus)
        }
    }

    public func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }

        if let ioProcID {
            AudioDeviceStop(aggregateDeviceID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateDeviceID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = kAudioObjectUnknown
        }
        if tapObjectID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapObjectID)
            tapObjectID = kAudioObjectUnknown
        }
        audioFormat = nil
    }

    private func handleAudioInput(_ inputData: UnsafePointer<AudioBufferList>?) {
        guard let inputData, let format = audioFormat else { return }

        let bufferListPtr = UnsafeMutablePointer(mutating: inputData)
        let numBuffers = Int(bufferListPtr.pointee.mNumberBuffers)
        let isInterleaved = !format.isInterleaved || numBuffers == 1

        let bytesPerFrame = UInt32(format.streamDescription.pointee.mBytesPerFrame)
        let firstBuffer = bufferListPtr.pointee.mBuffers
        let frameCount: UInt32
        if isInterleaved {
            frameCount = firstBuffer.mDataByteSize / max(bytesPerFrame, 1)
        } else {
            frameCount = firstBuffer.mDataByteSize / UInt32(format.streamDescription.pointee.mBytesPerPacket)
        }

        guard frameCount > 0 else { return }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        pcmBuffer.frameLength = frameCount

        if isInterleaved {
            if let srcData = firstBuffer.mData,
               let dstData = pcmBuffer.audioBufferList.pointee.mBuffers.mData {
                memcpy(dstData, srcData, Int(firstBuffer.mDataByteSize))
            }
        } else {
            let srcBuffers = bufferListPtr.withMemoryRebound(to: AudioBuffer.self, capacity: 1) { ptr in
                UnsafeRawPointer(ptr).advanced(by: MemoryLayout<UInt32>.size).assumingMemoryBound(to: AudioBuffer.self)
            }
            let dstBuffers = pcmBuffer.audioBufferList.withMemoryRebound(to: AudioBuffer.self, capacity: 1) { ptr in
                UnsafeRawPointer(ptr).advanced(by: MemoryLayout<UInt32>.size).assumingMemoryBound(to: AudioBuffer.self)
            }
            for i in 0..<numBuffers {
                if let srcData = srcBuffers[i].mData {
                    let dstData = dstBuffers[i].mData
                    if let dstData {
                        memcpy(dstData, srcData, Int(srcBuffers[i].mDataByteSize))
                    }
                }
            }
        }

        let level = calculateRMS(pcmBuffer)
        onLevelUpdate?(level)
        onAudioBuffer?(pcmBuffer)
    }

    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        let channels = Int(buffer.format.channelCount)
        var sum: Float = 0
        for ch in 0..<channels {
            let data = channelData[ch]
            for i in 0..<frameLength {
                sum += data[i] * data[i]
            }
        }
        let mean = sum / Float(frameLength * channels)
        return sqrt(mean)
    }

    private func getTapUID(_ tapID: AudioObjectID) throws -> String {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(tapID, &propAddr, 0, nil, &size, &uid)
        guard status == noErr, let uid else {
            throw AudioCaptureError.tapUIDFetchFailed(status)
        }
        return uid as String
    }

    private func createAggregateDevice(tapUID: String) throws -> AudioObjectID {
        let deviceUID = "com.recordit.aggregate.\(UUID().uuidString)"
        let tapDict: [String: Any] = [
            kAudioSubTapUIDKey: tapUID,
        ]
        let description: [String: Any] = [
            kAudioAggregateDeviceUIDKey: deviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapListKey: [tapDict],
        ]

        var deviceID = kAudioObjectUnknown
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)
        guard status == noErr else {
            throw AudioCaptureError.aggregateCreationFailed(status)
        }
        return deviceID
    }

    private func getStreamFormat(_ deviceID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &propAddr, 0, nil, &size, &format)
        guard status == noErr else {
            throw AudioCaptureError.formatFetchFailed(status)
        }
        return format
    }
}

public enum AudioCaptureError: LocalizedError {
    case tapCreationFailed(OSStatus)
    case tapUIDFetchFailed(OSStatus)
    case aggregateCreationFailed(OSStatus)
    case formatCreationFailed
    case formatFetchFailed(OSStatus)
    case ioProcCreationFailed(OSStatus)
    case deviceStartFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .tapCreationFailed(let s): return "Failed to create audio tap (error \(s))"
        case .tapUIDFetchFailed(let s): return "Failed to fetch tap UID (error \(s))"
        case .aggregateCreationFailed(let s): return "Failed to create aggregate device (error \(s))"
        case .formatCreationFailed: return "Failed to create audio format"
        case .formatFetchFailed(let s): return "Failed to fetch stream format (error \(s))"
        case .ioProcCreationFailed(let s): return "Failed to create IO proc (error \(s))"
        case .deviceStartFailed(let s): return "Failed to start audio device (error \(s))"
        }
    }
}
