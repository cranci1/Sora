//
//  VideoPlayer.swift
//  Sora
//
//  Created by Francesco on 27/005/25.

import GroupActivities

struct WatchTogetherActivity: GroupActivity {
    let streamUrl: String
    let mediaTitle: String
    let episodeNumber: Int
    
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.type = .watchTogether
        metadata.title = mediaTitle
        metadata.subtitle = "Episode \(episodeNumber)"
        return metadata
    }
}
