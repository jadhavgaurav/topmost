import SwiftUI

/// Main Settings window container with native macOS tab navigation.
public struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var permissions: PermissionManager
    @ObservedObject var loginItem: LoginItemManager

    public init(
        settings: SettingsManager = .shared,
        permissions: PermissionManager = .shared,
        loginItem: LoginItemManager = .shared
    ) {
        self.settings = settings
        self.permissions = permissions
        self.loginItem = loginItem
    }

    public var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings, loginItem: loginItem)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AppearanceFeedbackTab(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            WindowBehaviorTab(settings: settings)
                .tabItem {
                    Label("Behavior", systemImage: "macwindow.on.rectangle")
                }

            PermissionsTab(permissions: permissions)
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised")
                }

            AboutTab(settings: settings)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
        .padding()
        .onAppear {
            permissions.checkPermissions()
            loginItem.checkStatus()
        }
    }
}

// MARK: - General Tab
struct GeneralSettingsTab: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var loginItem: LoginItemManager

    var body: some View {
        Form {
            Section(header: Text("Startup & Integration").font(.headline)) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))

                Toggle("Show Menu Bar Icon", isOn: $settings.showMenuBarIcon)
            }

            Section(header: Text("Global Shortcuts").font(.headline)) {
                HStack {
                    Text("Pin / Unpin Current Window:")
                    Spacer()
                    Text(HotkeyManager.stringRepresentation(
                        modifiers: settings.hotkeyModifiers,
                        keyCode: settings.hotkeyCode
                    ))
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }

                Toggle("Enable \"Unpin Most Recent\" Shortcut", isOn: $settings.unpinRecentEnabled)
                    .onChange(of: settings.unpinRecentEnabled) { _, _ in
                        HotkeyManager.shared.registerCurrentHotkeys()
                    }

                if settings.unpinRecentEnabled {
                    HStack {
                        Text("Unpin Most Recent Shortcut:")
                        Spacer()
                        Text(HotkeyManager.stringRepresentation(
                            modifiers: settings.unpinRecentModifiers,
                            keyCode: settings.unpinRecentCode
                        ))
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance & Feedback Tab
struct AppearanceFeedbackTab: View {
    @ObservedObject var settings: SettingsManager

    let presetColors: [(name: String, hex: String, color: Color)] = [
        ("Blue (Default)", "#007AFF", Color(red: 0.0, green: 0.48, blue: 1.0)),
        ("Green", "#34C759", Color(red: 0.2, green: 0.78, blue: 0.35)),
        ("Orange", "#FF9500", Color(red: 1.0, green: 0.58, blue: 0.0)),
        ("Purple", "#AF52DE", Color(red: 0.69, green: 0.32, blue: 0.87)),
        ("Yellow", "#FFCC00", Color(red: 1.0, green: 0.8, blue: 0.0)),
        ("Red", "#FF3B30", Color(red: 1.0, green: 0.23, blue: 0.19))
    ]

    var body: some View {
        Form {
            Section(header: Text("Pin Outline").font(.headline)) {
                Toggle("Show pin outline", isOn: $settings.showOutline)
                    .onChange(of: settings.showOutline) { _, _ in
                        PinManager.shared.refreshVisualPreferences()
                    }

                if settings.showOutline {
                    Picker("Outline Color", selection: $settings.outlineColorHex) {
                        ForEach(presetColors, id: \.hex) { preset in
                            HStack {
                                Circle().fill(preset.color).frame(width: 12, height: 12)
                                Text(preset.name)
                            }
                            .tag(preset.hex)
                        }
                    }
                    .onChange(of: settings.outlineColorHex) { _, _ in
                        PinManager.shared.refreshVisualPreferences()
                    }

                    HStack {
                        Text("Thickness:")
                        Slider(value: $settings.outlineThickness, in: 1...5, step: 1)
                            .onChange(of: settings.outlineThickness) { _, _ in
                                PinManager.shared.refreshVisualPreferences()
                            }
                        Text("\(Int(settings.outlineThickness)) px")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Section(header: Text("Audio Feedback").font(.headline)) {
                Toggle("Play sound effects on pin / unpin", isOn: $settings.playSounds)

                if settings.playSounds {
                    HStack {
                        Text("Sound Volume:")
                        Slider(value: $settings.soundVolume, in: 0.0...1.0)
                        Text("\(Int(settings.soundVolume * 100))%")
                            .frame(width: 45, alignment: .trailing)
                    }

                    Button("Test Confirmation Sound") {
                        FeedbackManager.shared.playPinSound()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Window Behavior Tab
struct WindowBehaviorTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(header: Text("Pinning & Spaces").font(.headline)) {
                Toggle("Allow Multiple Pinned Windows", isOn: $settings.multiWindowPinning)
                Toggle("Keep Pinned Windows Visible Across Spaces", isOn: $settings.showAcrossSpaces)
            }

            Section(header: Text("Interaction Mode").font(.headline)) {
                Picker("When Clicking Floating Overlay:", selection: $settings.overlayClickBehavior) {
                    ForEach(OverlayClickBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Bringing the real window forward gives instant native keyboard focus and full input support.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Performance").font(.headline)) {
                Picker("Maximum Frame Rate:", selection: $settings.maxFrameRate) {
                    Text("15 FPS (Battery Saver)").tag(15)
                    Text("30 FPS (Standard)").tag(30)
                    Text("60 FPS (Ultra Smooth)").tag(60)
                }

                Toggle("Low Resource Mode", isOn: $settings.lowResourceMode)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Permissions Tab
struct PermissionsTab: View {
    @ObservedObject var permissions: PermissionManager

    var body: some View {
        Form {
            Section(header: Text("System Permissions").font(.headline)) {
                // Accessibility
                HStack(alignment: .top) {
                    Image(systemName: permissions.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(permissions.hasAccessibilityPermission ? .green : .orange)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility Permission")
                            .font(.headline)
                        Text("Required to identify the currently focused application window and track its position and size when moved.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !permissions.hasAccessibilityPermission {
                        Button("Open Settings") {
                            permissions.openAccessibilitySettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundColor(.green)
                            .font(.callout)
                    }
                }
                .padding(.vertical, 4)

                Divider()

                // Screen Recording
                HStack(alignment: .top) {
                    Image(systemName: permissions.hasScreenRecordingPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(permissions.hasScreenRecordingPermission ? .green : .orange)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen Recording Permission")
                            .font(.headline)
                        Text("Required by ScreenCaptureKit to stream the contents of explicitly pinned windows into floating overlays.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !permissions.hasScreenRecordingPermission {
                        Button("Open Settings") {
                            permissions.openScreenRecordingSettings()
                        }
                    } else {
                        Text("Granted")
                            .foregroundColor(.green)
                            .font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button("Re-check Permissions") {
                    permissions.checkPermissions()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            permissions.startPolling(interval: 1.0)
        }
        .onDisappear {
            permissions.stopPolling()
        }
    }
}

// MARK: - About Tab
struct AboutTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pin.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text("Topmost")
                    .font(.title2.bold())
                Text("Version 0.1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Always on Top Utility for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Developer:")
                    Spacer()
                    Text("jadhavgaurav")
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("License:")
                    Spacer()
                    Text("MIT License")
                        .foregroundColor(.primary)
                }

                HStack {
                    Text("Source Code:")
                    Spacer()
                    Link("github.com/jadhavgaurav/topmost", destination: URL(string: "https://github.com/jadhavgaurav/topmost")!)
                }
            }
            .font(.callout)
            .padding(.horizontal, 20)

            Spacer()

            HStack {
                Button("Report an Issue") {
                    if let url = URL(string: "https://github.com/jadhavgaurav/topmost/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Spacer()

                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                }
            }
        }
        .padding()
    }
}
