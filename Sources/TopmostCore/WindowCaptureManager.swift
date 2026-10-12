import Cocoa
import ScreenCaptureKit
import CoreMedia
import CoreVideo

/// Delegate protocol for capture events and frame delivery
public protocol WindowCaptureManagerDelegate: AnyObject {
    func captureManager(_ manager: WindowCaptureManager, didOutputIOSurface surface: IOSurface)
    func captureManager(_ manager: WindowCaptureManager, didFailWithError error: Error)
}

/// Hardware-accelerated window capture pipeline using ScreenCaptureKit
public final class WindowCaptureManager: NSObject, SCStreamOutput, SCStreamDelegate {
    public let windowID: CGWindowID
    public weak var delegate: WindowCaptureManagerDelegate?

    private var stream: SCStream?
    private let captureQueue = DispatchQueue(label: "com.topmost.captureQueue", qos: .userInteractive)
    private var isRunning = false
    private let settings: SettingsManager

    public init(windowID: CGWindowID, settings: SettingsManager = .shared) {
        self.windowID = windowID
        self.settings = settings
        super.init()
    }

    deinit {
        stop()
    }

    /// Starts ScreenCaptureKit streaming for the specific window
    public func start(initialSize: CGSize, scaleFactor: CGFloat) async throws {
        guard !isRunning else { return }

        // 1. Locate SCWindow
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let targetWindow = content.windows.first(where: { $0.windowID == self.windowID }) else {
            throw PinError.captureFailed("Window with ID \(windowID) not found in shareable content")
        }

        // 2. Configure content filter strictly for this independent window
        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)

        // 3. Configure stream parameters
        let config = SCStreamConfiguration()
        let width = max(Int(initialSize.width * scaleFactor), 32)
        let height = max(Int(initialSize.height * scaleFactor), 32)
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let fps = settings.lowResourceMode ? min(settings.maxFrameRate, 15) : settings.maxFrameRate
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))

        // 4. Create and start stream
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)

        try await newStream.startCapture()
        self.stream = newStream
        self.isRunning = true
    }

    /// Update capture stream dimensions when source window resizes
    public func updateDimensions(size: CGSize, scaleFactor: CGFloat) {
        guard isRunning, let stream = stream else { return }
        let config = SCStreamConfiguration()
        config.width = max(Int(size.width * scaleFactor), 32)
        config.height = max(Int(size.height * scaleFactor), 32)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let fps = settings.lowResourceMode ? min(settings.maxFrameRate, 15) : settings.maxFrameRate
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))

        stream.updateConfiguration(config) { error in
            if let error = error {
                NSLog("[Topmost] Error updating capture stream dimensions: %@", error.localizedDescription)
            }
        }
    }

    /// Stops and releases the capture stream
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        if let s = stream {
            s.stopCapture { _ in }
            self.stream = nil
        }
    }

    // MARK: - SCStreamOutput
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Use zero-copy IOSurface
        if let ioSurface = CVPixelBufferGetIOSurface(imageBuffer)?.takeUnretainedValue() {
            delegate?.captureManager(self, didOutputIOSurface: ioSurface)
        }
    }

    // MARK: - SCStreamDelegate
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        isRunning = false
        delegate?.captureManager(self, didFailWithError: error)
    }
}
