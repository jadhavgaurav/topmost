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

    private let captureQueue = DispatchQueue(label: "com.topmost.captureQueue", qos: .userInteractive)
    private let settings: SettingsManager

    /// Guards `stream`, `isRunning` and `isStopped`. `start` is async and may be suspended while
    /// `stop` is called from another thread, so every state transition goes through this lock.
    private let stateLock = NSLock()
    private var stream: SCStream?
    private var isRunning = false
    private var isStopped = false

    public init(windowID: CGWindowID, settings: SettingsManager = .shared) {
        self.windowID = windowID
        self.settings = settings
        super.init()
    }

    deinit {
        stop()
    }

    /// Starts ScreenCaptureKit streaming for the specific window.
    /// If `stop()` is called while this is suspended, the half-started stream is torn down
    /// instead of being left running with nobody to receive its frames.
    public func start(initialSize: CGSize, scaleFactor: CGFloat) async throws {
        guard !isStoppedOrRunning() else { return }

        // 1. Locate SCWindow
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let targetWindow = content.windows.first(where: { $0.windowID == self.windowID }) else {
            throw PinError.captureFailed("Window with ID \(windowID) not found in shareable content")
        }
        guard !isStoppedOrRunning() else { return }

        // 2. Configure content filter strictly for this independent window
        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)

        // 3. Create and start stream
        let configuration = makeConfiguration(size: initialSize, scaleFactor: scaleFactor)
        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
        try await newStream.startCapture()

        let accepted: Bool = stateLock.withLock {
            guard !isStopped else { return false }
            stream = newStream
            isRunning = true
            return true
        }

        if !accepted {
            try? newStream.removeStreamOutput(self, type: .screen)
            try? await newStream.stopCapture()
        }
    }

    private func isStoppedOrRunning() -> Bool {
        stateLock.withLock { isStopped || isRunning }
    }

    private func makeConfiguration(size: CGSize, scaleFactor: CGFloat) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(Int(size.width * scaleFactor), 32)
        config.height = max(Int(size.height * scaleFactor), 32)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let requested = settings.lowResourceMode ? min(settings.maxFrameRate, 15) : settings.maxFrameRate
        let fps = max(requested, 1)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        return config
    }

    private func currentStream() -> SCStream? {
        stateLock.withLock { isRunning ? stream : nil }
    }

    /// Update capture stream dimensions when source window resizes
    public func updateDimensions(size: CGSize, scaleFactor: CGFloat) {
        applyConfiguration(size: size, scaleFactor: scaleFactor, failureContext: "dimensions")
    }

    /// Dynamically refresh stream frame rate and low resource settings
    public func refreshConfiguration(size: CGSize, scaleFactor: CGFloat) {
        applyConfiguration(size: size, scaleFactor: scaleFactor, failureContext: "capture configuration")
    }

    private func applyConfiguration(size: CGSize, scaleFactor: CGFloat, failureContext: String) {
        guard let stream = currentStream() else { return }
        stream.updateConfiguration(makeConfiguration(size: size, scaleFactor: scaleFactor)) { error in
            if let error = error {
                NSLog("[Topmost] Error updating %@: %@", failureContext, error.localizedDescription)
            }
        }
    }

    /// Stops and releases the capture stream. Safe to call at any point, including while `start` is in flight.
    public func stop() {
        let activeStream: SCStream? = stateLock.withLock {
            isStopped = true
            isRunning = false
            let s = stream
            stream = nil
            return s
        }
        if let s = activeStream {
            try? s.removeStreamOutput(self, type: .screen)
            s.stopCapture { _ in }
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
        let wasStopped: Bool = stateLock.withLock {
            let already = isStopped
            isRunning = false
            return already
        }
        guard !wasStopped else { return }
        delegate?.captureManager(self, didFailWithError: error)
    }
}
