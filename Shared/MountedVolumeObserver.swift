import AppKit

/// Keeps Finder's observation roots in sync without traversing mounted filesystems.
@MainActor
final class MountedVolumeObserver {
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []
    private let mountedVolumes: () -> [URL]?
    private let update: (Set<URL>) -> Void
    private var directories: Set<URL> = []
    private var hasVolumeSnapshot = false

    init(center: NotificationCenter = NSWorkspace.shared.notificationCenter,
         mountedVolumes: @escaping () -> [URL]? = {
             FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [])
         },
         update: @escaping (Set<URL>) -> Void) {
        self.center = center
        self.mountedVolumes = mountedVolumes
        self.update = update
        // Subscribe before the initial snapshot so a mount during startup is not missed.
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let name = notification.name
                let volume = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
                let oldVolume = notification.userInfo?[NSWorkspace.oldVolumeURLUserInfoKey] as? URL
                MainActor.assumeIsolated { self?.refresh(name: name, volume: volume, oldVolume: oldVolume) }
            })
        }
        refresh()
    }

    private func refresh(name: Notification.Name? = nil, volume: URL? = nil, oldVolume: URL? = nil) {
        var next: Set<URL> = [URL(fileURLWithPath: "/")]
        if volume != nil && hasVolumeSnapshot {
            next.formUnion(directories)
        } else if let volumes = mountedVolumes() {
            // Include network, hidden and custom mount locations. Retry a failed
            // initial snapshot on the next event, even if that event carries a URL.
            next.formUnion(volumes)
            hasVolumeSnapshot = true
        } else {
            // A failed enumeration is not evidence that all volumes were unmounted.
            next.formUnion(directories)
        }
        if let volume {
            // Enumeration can still contain an ejected volume when didUnmount fires.
            // Apply the event last so stale enumeration cannot override its paths.
            if name == NSWorkspace.didUnmountNotification {
                next.remove(volume)
            } else {
                if let oldVolume { next.remove(oldVolume) }
                next.insert(volume)
            }
        }
        guard next != directories else { return }
        directories = next
        update(next)
    }

    isolated deinit {
        for observer in observers { center.removeObserver(observer) }
    }
}
