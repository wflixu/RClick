# External and network volume observation (#148, #150, #155, #158)

Finder observation and file-operation authorization are separate. Registering a
security-scoped bookmark in the app does not add a Finder Sync observation root.

## Observation roots

The extension registers `/` once at startup, then every mounted volume. Apple
documents recursive subdirectory observation but does not promise traversal
across volume boundaries, so `/` alone does not cover a volume mounted under
`/Volumes`. Enumerate with `FileManager.mountedVolumeURLs(includingResourceValues
ForKeys:options:[])`, without filtering out network, hidden, or non-removable
volumes. No directory traversal or volume resource-value queries are needed.

Subscribe to `NSWorkspace.shared.notificationCenter` before taking the initial
snapshot. Apply mount/unmount/rename notification URLs directly to the current
set. A real temporary HFS+ DMG probe demonstrated that, during didUnmount, volume
enumeration can still return the ejected volume. Blindly rescanning on every
notification therefore leaves stale roots. Re-enumerate only when notification
URLs are unavailable or the initial snapshot has not succeeded; preserve the
previous set on enumeration failure and apply event paths after any retry. Assign
`directoryURLs` only when the set changes. Observer lifetime follows the
extension; UI-framework interaction and observer cleanup use the main actor.

## The volume's sidebar icon (#155, #158)

Observing a volume root is what makes Finder redraw that volume's sidebar icon
with the extension's own icon. RClick ships no sidebar iconset — the documented
way to supply one — so Finder falls back to the app icon: every external disk and
mounted disk image appears in the sidebar wearing RClick's icon. Measured on this
machine against the installed 2.3.0: mounting a DMG volume produced a sidebar
entry carrying RClick's app icon, while `/` (`Macintosh HD`) and every favourite
folder kept theirs. Badges were blamed twice for this symptom (#128, #155) and
measured false both times; they are not involved.

**Observing the volumes' contents instead of their roots does not work.** That
variant was implemented, and it removes the icon problem by never observing a
mount point — but it produced no menu anywhere on the volume, including inside
its folders. The reason is the sandbox: `application.sb` allows sandboxed apps to
read `(literal "/Volumes")` and nothing below it, and the extension holds no
bookmark for a user's volume, so its directory listing is denied and the volume
contributes no observation roots at all. A sandboxed FinderSync extension cannot
discover what is on a volume; it can only observe the volume.

So the extension observes volume roots and the sidebar icon is a known
consequence, accepted deliberately: a working menu on external disks is worth
more than their sidebar icon, and the alternative loses both. `#158` stays open
as a macOS limitation. If a future release wants the icon as well, the only route
seen so far is the documented sidebar iconset — an iconset in the containing app
with monochrome `sidebar_*.png` templates — which would have to be measured
before it is believed.

## Validation

- Release build and the complete existing test suite passed with
  `CODE_SIGNING_ALLOWED=NO` under Swift 6 and with signing enabled. Note that the
  test host must be signed: built with `CODE_SIGNING_ALLOWED=NO` it cannot open
  its App Group container, exits at launch, and the runner reports "hung before
  establishing connection" rather than a test failure.
- Regression test `notificationPathsOverrideStaleVolumeEnumeration` failed with
  rescan-only handling and passed after applying notification URLs.
- Tests cover startup volumes, simulated external/NAS/custom mount paths,
  mount/unmount/rename, duplicate events, failed enumeration and cleanup.
- A temporary DMG using the production observer and real NSWorkspace notifications
  produced `probe-volume-present=false → true → false` without restarting the
  observer. The DMG was ejected after the probe.
- The subdirectory variant was measured on this machine with a real USB volume
  (mounted at `/Volumes/UPAN`, folders at its root): the volume kept its own
  sidebar icon — the intended effect — and had no RClick menu anywhere, root or
  subfolder, which is why it was abandoned.
- Normal signing remains blocked by missing upstream provisioning profiles. This
  verifies observation-root management, not a signed Finder installation or
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
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html
- `/System/Library/Sandbox/Profiles/application.sb` (`(literal "/Volumes")`)
