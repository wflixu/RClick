# Quickstart Guide: RClick macOS Finder Context Menu Extension

## Setup and Installation
1. **Install RClick**: Download the latest version from the GitHub releases page and install the application
2. **Grant Permissions**: 
   - Open System Settings > Privacy & Security > Extensions
   - Enable "RClick Finder Extension" under "Finder Extensions"
   - You may need to restart Finder or your Mac after enabling
3. **Launch RClick**: Open the application to configure your context menu options

## Basic Usage
1. **Configure Context Menu Items**:
   - Open RClick application
   - Navigate to the "Context Menu Items" section
   - Enable or disable available actions (Copy Path, Delete, Create File, etc.)
   - Add custom file types to create from the context menu
   - Configure external applications to open files with

2. **Using Finder Context Menu**:
   - Navigate to any folder in Finder
   - Right-click on a file or folder
   - Select from the extended context menu options
   - For file creation: Right-click in an empty space in Finder, select "New File", then choose the file type

3. **Accessing Settings**:
   - RClick appears in the menu bar
   - Click the menu bar icon to access quick settings and preferences

## Key Features Walkthrough

### Copy Path
- **Scenario**: User wants to copy the path of a selected file
- **Steps**: 
  1. Select a file in Finder
  2. Right-click and select "Copy Path" from RClick menu
  3. The file's path is now available in the clipboard

### Create New Files
- **Scenario**: User wants to create a new JSON file
- **Steps**:
  1. Right-click in an empty area of Finder
  2. Choose "New File" → "JSON File" (or your custom file type)
  3. A new file is created with an appropriate default name

### Open with Custom Applications
- **Scenario**: User wants to open a folder with Terminal
- **Steps**:
  1. Select the folder in Finder
  2. Right-click and select "Open with Terminal" from RClick menu
  3. Terminal opens with the selected folder as the current directory

### Delete Files
- **Scenario**: User wants to permanently delete a file
- **Steps**:
  1. Select the file in Finder
  2. Right-click and select "Delete Permanently" from RClick menu
  3. Confirm the deletion in the warning dialog
  4. The file is permanently deleted (not moved to Trash)

## Configuration Examples

### Adding Custom File Types
1. Open RClick preferences
2. Go to "File Types" section
3. Click "Add Custom Type"
4. Enter a display name (e.g., "Pages Document")
5. Enter the file extension (e.g., ".pages")
6. Optionally select a template file
7. Click "Save"

### Customizing External Applications
1. Open RClick preferences
2. Go to "External Apps" section
3. Click "Add Application"
4. Select an installed application from your system
5. Add the file types it can handle
6. Set any command-line arguments if needed

## Troubleshooting Tips
- **Context menu items not appearing**: Verify the Finder extension is enabled in System Settings
- **File creation failing**: Check that you have write permissions to the current directory
- **Update notifications**: If auto-update is enabled, you'll be notified when new versions are available
- **Permissions issues**: Some system directories require special permissions to modify

## Verification Steps
1. Verify that the RClick menu appears when right-clicking in Finder
2. Test creating a new file of each configured type
3. Test copying the path of a file and pasting it elsewhere
4. Verify that custom external applications open correctly
5. Confirm that the menu bar icon displays and responds to clicks

## Internationalization
- RClick supports English as the primary language and Simplified Chinese as the secondary language
- Language can be changed in the application settings
- All user-facing text is localized according to the constitutional requirement