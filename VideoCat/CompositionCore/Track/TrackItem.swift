//
//  TrackItem.swift
//  VideoCat
//
//  Created by Vito on 21/09/2017.
//  Copyright © 2017 Vito. All rights reserved.
//

import AVFoundation

public class TrackItem {
    
    public var identifier: String
    public var resource: TrackResource
    public var configuration: TrackConfiguration
    
    public var videoTransition: VideoTransition?
    public var audioTransition: AudioTransition?
    
    init(resource: TrackResource) {
        identifier = ProcessInfo.processInfo.globallyUniqueString
        self.resource = resource
        configuration = TrackConfiguration()
    }
    
}

public extension TrackItem {
    func reloadTimelineDuration() {
        let duration = resource.timeRange.duration
        var timeRange = configuration.timelineTimeRange
        timeRange.duration = duration
        configuration.timelineTimeRange = timeRange
    }
}

let TrackItem_AudioChannelIdentifier1 = "1"
let TrackItem_AudioChannelIdentifier2 = "2"

extension TrackItem: CompositionTrackProvider {
    public func configure(compositionTrack: AVMutableCompositionTrack, channelID: String) {
        if let asset = resource.trackAsset {
            func insertTrackToCompositionTrack(_ track: AVAssetTrack) {
                do {
                    try compositionTrack.insertTimeRange(resource.timeRange, of: track, at: configuration.timelineTimeRange.start)
                } catch {
                    Log.error(error.localizedDescription)
                }
            }
            if compositionTrack.mediaType == .video {
                if let track = asset.tracks(withMediaType: .video).first {
                    compositionTrack.preferredTransform = track.preferredTransform
                    insertTrackToCompositionTrack(track)
                }
            } else if compositionTrack.mediaType == .audio {
                let tracks = asset.tracks(withMediaType: .audio)
                if channelID == TrackItem_AudioChannelIdentifier1 {
                    if tracks.count > 0 {
                        insertTrackToCompositionTrack(tracks[0])
                    }
                } else if channelID == TrackItem_AudioChannelIdentifier2 {
                    if tracks.count > 0 {
                        insertTrackToCompositionTrack(tracks[1])
                    }
                } else {
                    if let track = tracks.first {
                        insertTrackToCompositionTrack(track)
                    }
                }
            }
        }
    }
}

extension TrackItem: VideoCompositionProvider {
    
    public var timeRange: CMTimeRange {
        return configuration.timelineTimeRange
    }
    
    public func applyEffect(to sourceImage: CIImage, at time: CMTime, renderSize: CGSize) -> CIImage {
        var finalImage = sourceImage
        guard let track = resource.trackAsset?.tracks(withMediaType: .video).first else {
            return finalImage
        }
        
        finalImage = finalImage.flipYCoordinate().transformed(by: track.preferredTransform).flipYCoordinate()
        
        var transform = CGAffineTransform.identity
        switch configuration.videoConfiguration.baseContentMode {
        case .aspectFit:
            let fitTransform = CGAffineTransform.transform(by: finalImage.extent, aspectFitInRect: CGRect(origin: .zero, size: renderSize))
            transform = transform.concatenating(fitTransform)
        case .aspectFill:
            let fillTransform = CGAffineTransform.transform(by: finalImage.extent, aspectFillRect: CGRect(origin: .zero, size: renderSize))
            transform = transform.concatenating(fillTransform)
        }
        finalImage = finalImage.transformed(by: transform)
        return finalImage
    }
    
    
    public func configureAnimationLayer(in layer: CALayer) {
        // TODO: Support animation tool layer
    }

}

extension TrackItem: AudioProvider {
    public func configure(audioMixParameters: AVMutableAudioMixInputParameters) {
        let volume = configuration.audioConfiguration.volume
        audioMixParameters.setVolumeRamp(fromStartVolume: volume, toEndVolume: volume, timeRange: configuration.timelineTimeRange)
        
        let node = VolumeAudioProcessingNode.init()
        let chain = AudioProcessingChain(node: node)
        configuration.audioConfiguration.audioTapHolder?.audioProcessingChain = chain
        audioMixParameters.audioProcessingTapHolder = configuration.audioConfiguration.audioTapHolder
    }
}

extension TrackItem: TransitionableVideoProvider {
    
}

extension TrackItem: TransitionableAudioProvider {
    
    
}

private extension CIImage {
    func flipYCoordinate() -> CIImage {
        let flipYTransform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: extent.origin.y * 2 + extent.height)
        return transformed(by: flipYTransform)
    }
}

