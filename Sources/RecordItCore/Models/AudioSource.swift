import Foundation
import AppKit
import CoreAudio
import Darwin

public struct AudioSource: Identifiable, Hashable, Sendable {
    public let audioObjectID: AudioObjectID
    public let pid: pid_t
    public let name: String
    public let bundleIdentifier: String?

    /// Identified by PID: the underlying audio object can rotate between
    /// refreshes (e.g. when Safari's WebKit.GPU helper restarts), which
    /// must not reset the user's source selection.
    public var id: pid_t { pid }

    public static func == (lhs: AudioSource, rhs: AudioSource) -> Bool {
        lhs.pid == rhs.pid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }

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
        let helpersByResponsiblePID = processesByResponsiblePID()
        return apps.compactMap { app -> AudioSource? in
            // An app is recordable if *any* process attributed to it has a
            // Core Audio object. Requiring the main process to have one
            // excludes apps like Safari on modern macOS, where the main
            // process never emits audio — its WebKit.GPU helper does.
            let objectIDs = objectIDs(forAppPID: app.processIdentifier, helpersByResponsiblePID: helpersByResponsiblePID)
            guard let primaryID = objectIDs.first else { return nil }
            return AudioSource(
                audioObjectID: primaryID,
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

    /// Returns the Core Audio process object IDs for an app and any helper
    /// processes macOS attributes to it via responsibility, limited to
    /// processes Core Audio itself knows about.
    ///
    /// This is required for apps like Safari, whose audio is emitted by
    /// `com.apple.WebKit.GPU` — an XPC service living under the WebKit
    /// framework rather than in the app bundle. Tapping only the app's main
    /// process therefore records silence. The Core Audio object filter is
    /// load-bearing: a large app's responsibility tree includes unrelated
    /// services (e.g. Metal shader compilers), and tapping those too yields
    /// no audio at all.
    public static func processObjectIDs(forAppPID appPID: pid_t) -> [AudioObjectID] {
        objectIDs(forAppPID: appPID, helpersByResponsiblePID: processesByResponsiblePID())
    }

    private static func objectIDs(
        forAppPID appPID: pid_t,
        helpersByResponsiblePID helpers: [pid_t: [pid_t]]
    ) -> [AudioObjectID] {
        var attributedPIDs = [appPID]
        attributedPIDs.append(contentsOf: helpers[appPID] ?? [])
        return attributedPIDs.compactMap { processObjectID(for: $0) }
    }

    /// Maps each responsible PID to the processes macOS attributes to it via
    /// responsibility (helpers, XPC services) — one scan for all apps.
    public static func processesByResponsiblePID() -> [pid_t: [pid_t]] {
        var result: [pid_t: [pid_t]] = [:]
        for pid in allPIDs() {
            guard let responsible = responsiblePID(for: pid), responsible != pid else { continue }
            result[responsible, default: []].append(pid)
        }
        return result
    }

    /// All PIDs currently known to the system.
    public static func allPIDs() -> [pid_t] {
        // proc_listallpids(nil, 0) returns the *number* of PIDs, not bytes.
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        let buffer = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(count))
        defer { buffer.deallocate() }

        let written = proc_listallpids(buffer, count * Int32(MemoryLayout<pid_t>.size))
        guard written > 0 else { return [] }

        return Array(UnsafeBufferPointer(start: buffer, count: Int(written)))
    }

    /// The PID macOS holds responsible for the given process, if it resolves.
    public static func responsiblePID(for pid: pid_t) -> pid_t? {
        let responsible = _responsibility_get_pid_responsible_for_pid(pid)
        return responsible > 0 ? responsible : nil
    }
}

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func _responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t
