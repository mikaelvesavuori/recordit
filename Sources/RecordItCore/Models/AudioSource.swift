import Foundation
import AppKit
import CoreAudio

public struct AudioSource: Identifiable, Hashable, Sendable {
    public let audioObjectID: AudioObjectID
    public let pid: pid_t
    public let name: String
    public let bundleIdentifier: String?

    public var id: AudioObjectID { audioObjectID }

    public var icon: NSImage? {
        guard let bundleIdentifier else { return nil }
        return NSWorkspace.shared.icon(forFile: NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?.path ?? "")
    }

    public init(audioObjectID: AudioObjectID, pid: pid_t, name: String, bundleIdentifier: String?) {
        self.audioObjectID = audioObjectID
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum AudioSourceEnumerator {
    public static func runningApps() -> [AudioSource] {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        return apps.compactMap { app in
            guard let objectID = processObjectID(for: app.processIdentifier) else { return nil }
            return AudioSource(
                audioObjectID: objectID,
                pid: app.processIdentifier,
                name: app.localizedName ?? "Unknown",
                bundleIdentifier: app.bundleIdentifier
            )
        }.sorted { $0.name < $1.name }
    }

    public static func processObjectID(for pid: pid_t) -> AudioObjectID? {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var objectID: AudioObjectID = kAudioObjectUnknown
        var pidValue = pid
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propAddr,
            UInt32(MemoryLayout<pid_t>.size),
            &pidValue,
            &size,
            &objectID
        )
        guard status == noErr, objectID != kAudioObjectUnknown else { return nil }
        return objectID
    }
}
