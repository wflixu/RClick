# External and network volume observation (#148, #150)

Finder observation and file-operation authorization are separate. Registering a
security-scoped bookmark in the app does not add a Finder Sync observation root.
The old extension registered only `/`, once at startup. It neither enumerated
mounted volumes nor handled volume lifecycle changes.

Apple documents recursive subdirectory observation, but does not explicitly
promise traversal across volume boundaries. Adding `/Volumes` alone still relies
on that assumption and misses volumes mounted elsewhere. Register `/` plus all
URLs from `FileManager.mountedVolumeURLs(includingResourceValuesForKeys:nil,
options:[])`, without filtering out network, hidden, or non-removable volumes.
No directory traversal or volume resource-value queries are needed.

Subscribe to `NSWorkspace.shared.notificationCenter` before taking the initial
snapshot. Apply mount/unmount/rename notification URLs directly to the current
set. A real temporary HFS+ DMG probe demonstrated that, during didUnmount, volume
enumeration can still return the ejected volume. Blindly rescanning on every
notification therefore leaves stale roots. Re-enumerate only when notification
URLs are unavailable or the initial snapshot has not succeeded; preserve the
previous set on enumeration failure and apply event paths after any retry. Assign
`directoryURLs` only when the set changes. Observer lifetime follows the extension;
UI-framework interaction and observer cleanup use the main actor.

## Validation

- Release build and the complete existing test suite passed with
  `CODE_SIGNING_ALLOWED=NO` under Swift 6.
- Regression test `notificationPathsOverrideStaleVolumeEnumeration` failed with
  rescan-only handling and passed after applying notification URLs.
- Tests cover startup volumes, simulated external/NAS/custom mount paths,
  mount/unmount/rename, duplicate events, failed enumeration and cleanup.
- A temporary DMG using the production observer and real NSWorkspace notifications
  produced `probe-volume-present=false → true → false` without restarting the
  observer. The DMG was ejected after the probe.
- Normal signing remains blocked by missing upstream provisioning profiles.
  This verifies observation-root management, not a signed Finder installation or
  physical USB / SMB / NFS / AFP menu appearance and action execution.

After signing and enabling the extension, check a volume mounted before launch,
a USB drive and NAS mounted while running, a mounted DMG, rename/eject/remount,
and a normal local folder. Check menus inside each volume as well as on its root;
then verify an innocuous action such as Copy Path. File Provider-managed locations
and sandbox permissions are separate concerns; this change does not bypass them.

Sources:
- https://developer.apple.com/documentation/findersync/fifindersynccontroller/directoryurls
- https://developer.apple.com/documentation/foundation/filemanager/mountedvolumeurls(includingresourcevaluesforkeys:options:)
- https://developer.apple.com/documentation/appkit/nsworkspace/didmountnotification
- https://developer.apple.com/documentation/appkit/nsworkspace/didunmountnotification
- https://developer.apple.com/documentation/appkit/nsworkspace/didrenamevolumenotification
