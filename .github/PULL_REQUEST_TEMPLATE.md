## Summary

<!-- Briefly describe what this PR does and why -->

## Type of Change

- [ ] 🐛 Bug fix
- [ ] ✨ New feature
- [ ] 📝 Documentation update
- [ ] ♻️ Refactoring
- [ ] ⚡ Performance improvement
- [ ] 🔧 Build/CI change
- [ ] 🧪 Test addition/update

## Related Issue

<!-- Link to the issue this PR addresses, e.g., "Closes #123" -->

## Screenshots

<!-- If your change affects the UI, include before/after screenshots -->

| Before | After |
|--------|-------|
|        |       |

## Testing

### Manual Testing

<!-- Describe the steps you followed to verify your changes -->

- [ ] App launches and appears in menu bar
- [ ] Right-click menu works correctly in Finder
- [ ] Dark mode looks correct
- [ ] Settings persist across restarts
- [ ] FinderSync extension loads properly

### Build Verification

```bash
# Paste the output of:
xcodebuild -project RClick.xcodeproj -scheme RClick -destination 'platform=macOS'
```

## Checklist

- [ ] My code follows the project's Swift 6.2 conventions (see [CONTRIBUTING.md](CONTRIBUTING.md))
- [ ] All UI is SwiftUI (no AppKit UI components)
- [ ] I have tested on macOS 15.6+
- [ ] I have tested with both light and dark mode
- [ ] I have updated documentation if needed
- [ ] My branch is up-to-date with `dev`

## Additional Notes

<!-- Any other context the reviewer should know -->
