//
//  SharePlayCoordinator.swift
//  Sora
//
//  Created by Francesco on 15/06/25.
//

import Combine
import Foundation
import AVFoundation
import GroupActivities

@MainActor
class SharePlayCoordinator: ObservableObject {
    private var subscriptions = Set<AnyCancellable>()
    private var groupSession: GroupSession<VideoWatchingActivity>?
    
    @Published var isEligibleForGroupSession = false
    @Published var groupSessionState: GroupSession<VideoWatchingActivity>.State = .waiting
    
    private var playbackCoordinator: AVPlayerPlaybackCoordinator?
    
    func configureGroupSession() {
        Task {
            for await session in VideoWatchingActivity.sessions() {
                await configureGroupSession(session)
            }
        }
    }
    
    private func configureGroupSession(_ groupSession: GroupSession<VideoWatchingActivity>) async {
        self.groupSession = groupSession
        
        groupSession.$state
            .receive(on: DispatchQueue.main)
            .assign(to: &$groupSessionState)
        
        groupSession.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { participants in
                Logger.shared.log("Active participants: \(participants.count)", type: "SharePlay")
            }
            .store(in: &subscriptions)
        
        groupSession.join()
    }
    
    func startSharePlay(with activity: VideoWatchingActivity) async {
        do {
            _ = try await activity.activate()
            Logger.shared.log("SharePlay activity activated successfully", type: "SharePlay")
        } catch {
            Logger.shared.log("Failed to activate SharePlay: \(error.localizedDescription)", type: "Error")
        }
    }
    
    func coordinatePlayback(with player: AVPlayer) {
        guard let groupSession = groupSession else { return }
        
        playbackCoordinator = player.playbackCoordinator
        playbackCoordinator?.coordinateWithSession(groupSession)
        
        Logger.shared.log("Playback coordination established", type: "SharePlay")
    }
    
    nonisolated func leaveGroupSession() {
        Task { @MainActor in
            self.groupSession?.leave()
            self.playbackCoordinator = nil
            Logger.shared.log("Left SharePlay session", type: "SharePlay")
        }
    }
    
    deinit {
        subscriptions.removeAll()
        playbackCoordinator = nil
    }
}
