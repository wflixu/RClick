import AppKit
import Testing
@testable import RClick

@MainActor
struct MountedVolumeObserverTests {
    @Test func tracksStartupMountRenameAndUnmountWithoutRestart() {
        let center = NotificationCenter()
        let root = URL(fileURLWithPath: "/")
        let disk = URL(fileURLWithPath: "/Volumes/External Disk")
        let nas = URL(fileURLWithPath: "/Volumes/NAS")
        let dmg = URL(fileURLWithPath: "/Volumes/Installer")
        let renamed = URL(fileURLWithPath: "/Volumes/Renamed Disk")
        let custom = URL(fileURLWithPath: "/mnt/nfs")
        var volumes: [URL]? = [root, disk, nas, custom]
        var updates: [Set<URL>] = []
        let observer = MountedVolumeObserver(center: center, mountedVolumes: { volumes }) {
            updates.append($0)
        }
        withExtendedLifetime(observer) {
            #expect(updates.last == [root, disk, nas, custom])
            volumes?.append(dmg)
            center.post(name: NSWorkspace.didMountNotification, object: nil)
            #expect(updates.last == [root, disk, nas, custom, dmg])
            volumes = [root, renamed, nas, custom, dmg]
            center.post(name: NSWorkspace.didRenameVolumeNotification, object: nil)
            #expect(updates.last == [root, renamed, nas, custom, dmg])
            volumes = [root, nas, custom]
            center.post(name: NSWorkspace.didUnmountNotification, object: nil)
            #expect(updates.last == [root, nas, custom])
            #expect(updates.count == 4)
            center.post(name: NSWorkspace.didMountNotification, object: nil)
            #expect(updates.count == 4)
            volumes = nil
            center.post(name: NSWorkspace.didUnmountNotification, object: nil)
            #expect(updates.last == [root, nas, custom])
            #expect(updates.count == 4)
            volumes = []
            center.post(name: NSWorkspace.didUnmountNotification, object: nil)
            #expect(updates.last == [root])
        }
    }

    @Test func failedInitialEnumerationRecoversAndObserversAreReleased() {
        let center = NotificationCenter()
        var volumes: [URL]?
        var reads = 0
        var updates: [Set<URL>] = []
        var observer: MountedVolumeObserver? = MountedVolumeObserver(center: center, mountedVolumes: {
            reads += 1
            return volumes
        }, update: { updates.append($0) })
        weak var weakObserver = observer
        #expect(reads == 1)
        #expect(updates.last == [URL(fileURLWithPath: "/")])
        let nas = URL(fileURLWithPath: "/Volumes/Reconnected NAS")
        let existing = URL(fileURLWithPath: "/Volumes/Already Mounted")
        volumes = [nas, existing]
        center.post(name: NSWorkspace.didMountNotification, object: nil,
                    userInfo: [NSWorkspace.volumeURLUserInfoKey: nas])
        #expect(reads == 2)
        #expect(updates.last == [URL(fileURLWithPath: "/"), nas, existing])
        observer = nil
        #expect(weakObserver == nil)
        center.post(name: NSWorkspace.didMountNotification, object: nil)
        #expect(reads == 2)
    }
    @Test func notificationPathsOverrideStaleVolumeEnumeration() {
        let center = NotificationCenter()
        let root = URL(fileURLWithPath: "/")
        let old = URL(fileURLWithPath: "/Volumes/Old")
        let new = URL(fileURLWithPath: "/Volumes/New")
        var snapshot = [old]
        var latest: Set<URL> = []
        let observer = MountedVolumeObserver(center: center, mountedVolumes: { snapshot }) { latest = $0 }
        withExtendedLifetime(observer) {
            // Real NSWorkspace unmount notifications can precede the enumeration update.
            center.post(name: NSWorkspace.didUnmountNotification, object: nil,
                        userInfo: [NSWorkspace.volumeURLUserInfoKey: old])
            #expect(latest == [root])
            snapshot = []
            center.post(name: NSWorkspace.didMountNotification, object: nil,
                        userInfo: [NSWorkspace.volumeURLUserInfoKey: old])
            #expect(latest == [root, old])
            snapshot = [old]
            center.post(name: NSWorkspace.didRenameVolumeNotification, object: nil,
                        userInfo: [NSWorkspace.volumeURLUserInfoKey: new,
                                   NSWorkspace.oldVolumeURLUserInfoKey: old])
            #expect(latest == [root, new])
        }
    }

}
