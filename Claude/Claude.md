

```markdown
# Project Overview & Architecture

## Product Positioning
A macOS Menu Bar application that provides quick Git operations and file management for the current Finder window. Users can commit & push changes or create README files with a single click from the menu bar.

## Core Features
1. **Git Quick Commit & Push**: Opens a multi-line input dialog for commit message, then executes `git add . && git commit -m "<message>" && git push origin <branch>`
2. **Create README.md**: Creates an empty README.md file in the current Finder directory
3. **Settings Panel**: Configure default branch name and toggle button visibility

## Key Business Rules
- Menu displays current Finder path at top, followed by available action buttons
- "Create README" button is hidden if README.md already exists in target directory
- Git errors display in alert dialog with full error message
- Commit message input pre-filled with current date-time (format: "YYYY-MM-DD HH:mm")
- During Git execution: menu bar icon shows loading animation, completion triggers notification
- All operations target the frontmost Finder window path (obtained via AppleScript)

---

# Tech Stack & Dependencies

## Core Runtime
- **Language**: Swift 5.7+
- **UI Framework**: SwiftUI (targeting macOS 12 Monterey minimum)
- **Build System**: Xcode 14+, SPM for any future dependencies

## Key System Integrations
- **AppleScript Bridge**: `NSAppleScript` to query Finder window path
- **Process Execution**: `Process` (formerly `NSTask`) for git commands
- **Permissions Required**: Automation access for Finder (user must grant in System Preferences → Privacy & Security → Automation)
- **User Defaults**: Persist settings (branch name, button visibility flags)
- **User Notifications**: `UNUserNotificationCenter` for operation completion feedback

## No External Dependencies
Use system `git` (assumed at `/usr/bin/git` or in user's PATH). Do not bundle or install git.

---

# Directory Structure & Conventions

```
FinderGitHelper/
├── FinderGitHelper.xcodeproj
├── FinderGitHelper/
│   ├── FinderGitHelperApp.swift          # @main entry, MenuBarExtra setup
│   ├── Models/
│   │   ├── AppSettings.swift             # UserDefaults wrapper for branch & visibility
│   │   └── FinderPathResult.swift        # Result type for path detection
│   ├── ViewModels/
│   │   ├── MenuBarViewModel.swift        # Handles path detection, git ops, README creation
│   │   └── SettingsViewModel.swift       # Manages settings persistence
│   ├── Views/
│   │   ├── MenuBarContentView.swift      # Main menu: path + buttons
│   │   ├── CommitMessageView.swift       # Multi-line input sheet for commit message
│   │   └── SettingsView.swift            # Settings window
│   ├── Services/
│   │   ├── FinderService.swift           # AppleScript execution for path
│   │   ├── GitService.swift              # Git command execution wrapper
│   │   └── NotificationService.swift     # User notification helper
│   ├── Utilities/
│   │   └── DateFormatter+Extensions.swift # Format for commit message template
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       └── MenuBarIcon.imageset/         # SF Symbol or custom icon
├── Info.plist
└── README.md
```

## Architecture Layers
1. **App Layer**: `@main` struct, MenuBarExtra initialization
2. **View Layer**: SwiftUI views (no business logic, presentation only)
3. **ViewModel Layer**: ObservableObject classes coordinating services
4. **Service Layer**: Stateless utility classes for external interactions
5. **Model Layer**: Codable structs for settings, plain structs for data transfer

---

# Codex Operational Rules

## Pre-execution Checklist
Before modifying any code:
1. Read `AppSettings.swift` to understand current configuration schema
2. Check `MenuBarViewModel.swift` for state management patterns
3. Review `Info.plist` for required permissions keys

## Coding Constraints

### Swift & SwiftUI Standards
- **SwiftUI Lifecycle**: Use `@main` struct conforming to `App`, no AppDelegate/SceneDelegate
- **State Management**: Use `@StateObject` in root views, `@ObservedObject` in child views, `@Published` in ViewModels
- **Async Operations**: Use `Task {}` blocks for async work, never block main thread
- **Error Handling**: All shell/AppleScript operations must return `Result<T, Error>` types

### Process Execution Safety
```swift
// Correct pattern for git commands
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
process.arguments = ["add", "."]
process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

let outputPipe = Pipe()
let errorPipe = Pipe()
process.standardOutput = outputPipe
process.standardError = errorPipe

try process.run()
process.waitUntilExit()

// Check exit code, read stderr for errors
if process.terminationStatus != 0 {
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
    return .failure(GitError.commandFailed(errorMessage))
}
```

### AppleScript Execution Pattern
```swift
let script = """
tell application "Finder"
    if (count of Finder windows) is 0 then
        return ""
    end if
    set currentFolder to (target of front window) as alias
    return POSIX path of currentFolder
end tell
"""

let appleScript = NSAppleScript(source: script)
var error: NSDictionary?
let result = appleScript?.executeAndReturnError(&error)

if let error = error {
    return .failure(FinderError.scriptFailed(error.description))
}
```

### Forbidden Patterns
- ❌ Do not use `shell` or `/bin/sh -c` for command execution (security risk)
- ❌ Do not hardcode file paths; always use `FileManager` and URL APIs
- ❌ Do not use force-unwrap (`!`) on Process results or AppleScript outputs
- ❌ Do not introduce third-party dependencies without explicit approval
- ❌ Do not use deprecated APIs (e.g., `NSTask` instead of `Process`)

### UserDefaults Keys Convention
```swift
// Define as static strings in AppSettings
static let defaultBranchKey = "defaultBranch"
static let showGitButtonKey = "showGitButton"
static let showReadmeButtonKey = "showReadmeButton"
```

### Commit Message Template Format
```swift
// Example: "2025-01-15 14:32"
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd HH:mm"
return formatter.string(from: Date())
```

## Testing & Verification

### Unit Tests Required
1. `GitService` command construction (mock Process execution)
2. `FinderService` AppleScript generation (verify script syntax)
3. `AppSettings` persistence (test UserDefaults read/write)
4. Date formatting for commit message template

### Manual Testing Checklist
- [ ] Menu bar icon appears and is clickable
- [ ] Menu displays correct Finder path (test with multiple windows)
- [ ] Menu displays "No Finder window" when no window is open
- [ ] Git button triggers commit message sheet
- [ ] Commit message pre-filled with date-time
- [ ] Cancel button dismisses sheet without action
- [ ] Confirm button starts git operation, shows loading animation
- [ ] Success notification appears after push completes
- [ ] Error alert displays full error message on failure
- [ ] README button hidden when file exists
- [ ] README button creates empty file and refreshes Finder
- [ ] Settings window opens and persists changes
- [ ] Button visibility toggles work immediately in menu

### Edge Cases to Handle
1. No Finder window open → Display message in menu, disable buttons
2. Finder window shows special location (Network, iCloud) → Detect and show error
3. Directory is not a git repository → Display clear error: "Not a git repository. Run 'git init' first."
4. No git changes to commit → Display error: "No changes to commit."
5. Network failure during push → Display error with timeout message
6. README.md exists → Button must not appear (re-check on menu open)
7. User denies Automation permission → Display setup instructions with deep link to System Preferences

---

# Verification Commands

## Build & Run
```bash
# Open project in Xcode
open FinderGitHelper.xcodeproj

# Build from CLI (optional)
xcodebuild -project FinderGitHelper.xcodeproj -scheme FinderGitHelper -configuration Debug build

# Run in Xcode: Cmd+R
# Menu bar icon should appear in system tray
```

## Code Quality
```bash
# SwiftLint (if added later)
swiftlint lint --strict

# Swift format check (manual for now)
# Ensure 4-space indentation, no trailing whitespace
```

## Testing
```bash
# Run unit tests in Xcode: Cmd+U
xcodebuild test -project FinderGitHelper.xcodeproj -scheme FinderGitHelper

# Manual test: Open a Finder window in a git repo, click menu bar icon, verify path displayed
```

---

# Phased Roadmap & Task Checklist

## Phase 1: Project Setup & Core Infrastructure
- [ ] Create new macOS App project in Xcode with SwiftUI, target macOS 12+
- [ ] Configure `Info.plist` with `NSAppleEventsUsageDescription` for Automation permission
- [ ] Add menu bar icon asset (SF Symbol: `terminal` or custom icon)
- [ ] Implement `FinderGitHelperApp.swift` with `MenuBarExtra` initialization
- [ ] Create `AppSettings.swift` with UserDefaults wrapper (branch, button visibility)

## Phase 2: Finder Path Detection
- [ ] Implement `FinderService.swift` with AppleScript execution method
- [ ] Create `FinderPathResult` enum: `.success(String)`, `.noWindow`, `.error(Error)`
- [ ] Test path detection with multiple Finder windows and edge cases
- [ ] Add error handling for Automation permission denial

## Phase 3: Git Operations
- [ ] Implement `GitService.swift` with methods: `addAll()`, `commit(message:)`, `push(branch:)`
- [ ] Create combined `commitAndPush(message:branch:path:)` method returning `Result<Void, GitError>`
- [ ] Handle all git error scenarios: not a repo, no changes, network failure, etc.
- [ ] Test with real git repositories (init test repo if needed)

## Phase 4: Menu Bar UI
- [ ] Implement `MenuBarViewModel.swift`:
  - `@Published var currentPath: String?`
  - `@Published var isLoading: Bool`
  - `@Published var readmeExists: Bool`
  - Methods: `refreshFinderPath()`, `executeGitOperation(_:)`, `createReadme()`
- [ ] Build `MenuBarContentView.swift`:
  - Display current path or "No Finder window"
  - Show Git button (if enabled in settings)
  - Show README button (if enabled and file doesn't exist)
  - Show Settings button
- [ ] Implement loading animation for menu bar icon (use `.symbolEffect()` or custom animation)

## Phase 5: Commit Message Input
- [ ] Create `CommitMessageView.swift` as sheet presentation:
  - `TextEditor` for multi-line input (binding to `@State var message: String`)
  - Pre-fill with date-time template in `onAppear`
  - Cancel and Confirm buttons
- [ ] Integrate sheet presentation in `MenuBarContentView` triggered by Git button
- [ ] Pass commit action closure from ViewModel

## Phase 6: README Creation
- [ ] Add `createReadme(at:)` method in `MenuBarViewModel`
- [ ] Use `FileManager.default.createFile(atPath:contents:attributes:)` with empty data
- [ ] Refresh `readmeExists` state after creation
- [ ] Trigger success notification

## Phase 7: Settings Window
- [ ] Implement `SettingsViewModel.swift` wrapping `AppSettings`
- [ ] Create `SettingsView.swift`:
  - TextField for default branch name
  - Toggle for "Show Git Button"
  - Toggle for "Show README Button"
- [ ] Add Settings button in menu opening settings window as separate `Window` group

## Phase 8: Notifications & Feedback
- [ ] Implement `NotificationService.swift` requesting authorization on first launch
- [ ] Send notifications for:
  - Git push success: "Changes pushed to <branch>"
  - Git operation failure: "Git operation failed" (with error in alert)
  - README created: "README.md created successfully"
- [ ] Ensure alerts display full error messages for debugging

## Phase 9: Polish & Edge Case Handling
- [ ] Add permission check on launch, show alert with instructions if denied
- [ ] Implement proper error recovery (e.g., retry logic for transient network errors)
- [ ] Add app icon and menu bar icon (SF Symbols or custom design)
- [ ] Test with non-git directories, special Finder locations
- [ ] Ensure UI updates happen on main thread (`@MainActor` or explicit dispatch)

## Phase 10: Documentation & Release Prep
- [ ] Write user-facing README.md with setup instructions (granting Automation permission)
- [ ] Add inline code documentation for public methods
- [ ] Create demo video/screenshots showing workflow
- [ ] Build Release configuration, verify code signing
- [ ] Test on clean macOS 12 and macOS 13+ systems

---

# Additional Notes for Codex

## Permission Setup Instructions (for README)
Users must grant Automation permission:
1. Open System Preferences → Security & Privacy → Privacy → Automation
2. Find "FinderGitHelper" in the list
3. Check the box next to "Finder"
4. Restart the app if already running

## Default Settings Values
- Default branch: `"main"`
- Show Git Button: `true`
- Show README Button: `true`

## Error Message Standards
All user-facing error alerts should:
- Use title: "Operation Failed"
- Display full stderr output from git commands
- Suggest remediation (e.g., "Ensure this directory is a git repository")

## Notification Behavior
- Request authorization in `NotificationService.init()` or app launch
- Use `.alert` style for errors, `.banner` for success
- Keep message text concise, under 100 characters

---

**End of Specification**