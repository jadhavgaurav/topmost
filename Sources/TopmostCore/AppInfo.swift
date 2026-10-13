import Foundation

/// Facts about the running build, read from the app bundle so the version has one source: Info.plist.
public enum AppInfo {
    /// For example "0.2.0 (2)". Falls back to "development" when run outside an app bundle,
    /// such as under `swift run`.
    public static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String else { return "development" }
        guard let build = info?["CFBundleVersion"] as? String, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }
}
