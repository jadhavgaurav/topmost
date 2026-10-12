# Topmost Testing Guide & Acceptance Verification

## Automated Test Suite

Topmost includes a comprehensive automated test suite covering all critical state management, coordinate conversions, shortcut parsing, and lifecycle logic.

### Running Automated Tests

```bash
./scripts/test.sh
```

### Verified Test Cases

| Test Case | Description | Status |
|---|---|---|
| **Test 1** | Window Identity Matching & Deterministic Hashing | **PASS** |
| **Test 2** | WindowInfo Dimensions & Coordinate Conversions | **PASS** |
| **Test 3** | Hotkey String Formatting & Normalization | **PASS** |
| **Test 4** | Settings Persistence & Boundary Clamping | **PASS** |
| **Test 5** | Pin State Transitions (Pin / Unpin / Active list) | **PASS** |
| **Test 6** | Multiple Pinned Windows & Unpin All | **PASS** |
| **Test 7** | Unpin Most Recent (Chronological tracking) | **PASS** |
| **Test 8** | Repeated Rapid Pin/Unpin Cycles (Race Safety) | **PASS** |
| **Test 9** | Permission Manager Queries & Polling | **PASS** |
| **Test 10** | PinError Descriptions & Diagnostics | **PASS** |

**Total Automated Tests:** 38 passed, 0 failed.

---

## Manual Real-World Test Plan

### Test Scenarios

1. **TextEdit Window Pinned while using Safari**
   - Open TextEdit with a document.
   - Focus TextEdit and press `Control + Command + P`.
   - Verify: 3px blue outline (`#007AFF`) appears around TextEdit window; subtle confirmation chime plays.
   - Switch to Safari and browse web pages.
   - Verify: TextEdit window stays floating above Safari windows.
   - Click the floating representation: TextEdit activates and receives native focus.

2. **Notes Window Pinned while using Chrome**
   - Focus Notes.app, press `Control + Command + P`.
   - Switch to Google Chrome and type in a document or search bar.
   - Verify: Notes remains visible above Chrome.

3. **Terminal Pinned while using Finder**
   - Focus Terminal, press `Control + Command + P`.
   - Open Finder and navigate directories.
   - Verify: Terminal remains visible.

4. **Multiple Windows from the Same Application**
   - Open two TextEdit windows.
   - Focus only the first window and press `Control + Command + P`.
   - Verify: Only the first window is pinned. The second window behaves as a normal desktop window.

5. **Window Movement and Resizing**
   - Drag the pinned window to another position.
   - Verify: Outline and overlay follow immediately.
   - Resize the window from its corners.
   - Verify: Outline and overlay resize dynamically.

6. **Source Window Closure**
   - Close the pinned source window with `Command + W` or the red titlebar button.
   - Verify: Outline and overlay disappear immediately; session is cleanly purged.

7. **Application Termination**
   - Quit the pinned application with `Command + Q`.
   - Verify: Pinned overlay is automatically removed without orphaned windows.

8. **Unpin All Action**
   - Pin 3 different windows.
   - Open the Topmost menu bar menu and click **Unpin All Windows**.
   - Verify: All 3 windows unpin immediately and descending confirmation sound plays.

9. **Switching Desktop Spaces**
   - Pin a window on Desktop 1.
   - Swipe with three fingers to Desktop 2.
   - Verify: The pinned window follows or remains visible across Spaces.

10. **Dark Mode & Light Mode Appearance**
    - Toggle macOS Dark Mode / Light Mode in System Settings.
    - Verify: Settings window and menu adapt natively.
