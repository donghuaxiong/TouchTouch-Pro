import Darwin
import Foundation

/// Controls media playback using the MediaRemote private framework.
/// Uses MRMediaRemoteSendCommand to trigger Previous/Next track,
/// which works with Apple Music, Spotify, and any Now Playing app.
final class MediaControlManager {

    private typealias SendCommand = @convention(c) (Int32, Any?) -> Void

    private let mrSendCommand: SendCommand?

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_LAZY),
              let fn = dlsym(handle, "MRMediaRemoteSendCommand")
        else {
            mrSendCommand = nil
            return
        }
        mrSendCommand = unsafeBitCast(fn, to: SendCommand.self)
    }

    // MARK: - Track Control

    /// Previous track (F7 / NX_KEYTYPE_PREVIOUS)
    func previousTrack() {
        mrSendCommand?(5, nil) // MRMediaRemoteCommandPreviousTrack = 5
    }

    /// Next track (F9 / NX_KEYTYPE_NEXT)
    func nextTrack() {
        mrSendCommand?(4, nil) // MRMediaRemoteCommandNextTrack = 4
    }
}
