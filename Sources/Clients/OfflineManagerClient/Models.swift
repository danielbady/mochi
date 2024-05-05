//
//  Models.swift
//
//
//  Created by DeNeRr on 06.04.2024.
//

import Foundation
import SharedModels
import Tagged

extension OfflineManagerClient {
  public enum Error: Swift.Error, Equatable, Sendable {
    case failedToGetPlaylistId
  }
  
  public enum RemoveType {
    case cache
    case download
    case all
  }
  
  public struct DownloadAsset: Equatable, Sendable {
    public let episodeMetadata: EpisodeMetadata
    public let episodeId: Playlist.Item.ID
    public let groups: [Playlist.Group]?
    public let playlist: Playlist
    public let details: Playlist.Details?
    public let repoModuleId: RepoModuleID
    
    public init(episodeMetadata: EpisodeMetadata, episodeId: Playlist.Item.ID, groups: [Playlist.Group]?, playlist: Playlist, details: Playlist.Details?, repoModuleId: RepoModuleID) {
      self.episodeMetadata = episodeMetadata
      self.episodeId = episodeId
      self.groups = groups
      self.playlist = playlist
      self.details = details
      self.repoModuleId = repoModuleId
    }
  }
  
  public struct CacheAsset: Equatable, Sendable {
    public let groups: [Playlist.Group]?
    public let playlist: Playlist
    public let details: Playlist.Details?
    public let repoModuleId: RepoModuleID
    
    public init(groups: [Playlist.Group]?, playlist: Playlist, details: Playlist.Details?, repoModuleId: RepoModuleID) {
      self.playlist = playlist
      self.details = details
      self.groups = groups
      self.repoModuleId = repoModuleId
    }
  }
  
  public struct DownloadingAsset: Hashable {
    public let url: URL
    public let playlistId: Playlist.ID
    public let episodeId: Playlist.Item.ID
    public let metadata: EpisodeMetadata
  }
}
