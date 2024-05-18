//
//  Live.swift
//
//
//  Created by DeNeRr on 06.04.2024.
//

import Dependencies
import Foundation
import FileClient
import AVFoundation
import UIKit
import SharedModels
import DatabaseClient
import FlyingFox
import OrderedCollections

// MARK: - OfflineManagerClient + DependencyKey

extension OfflineManagerClient: DependencyKey {
  @Dependency(\.fileClient) private static var fileClient
  private static let downloadManager = OfflineDownloadManager()
  
  public static let liveValue = Self(
    download: { asset in
      try? await downloadManager.setupAssetDownload(asset)
    },
    cache: { asset in
      let libraryFileUrl = try fileClient.retrieveLibraryDirectory(root: .playlistCache)
      let playlist = asset.playlist
      let playlistId = playlist.id.rawValue.replacingOccurrences(of: "/", with: "\\")
      let imageUrl = libraryFileUrl.appendingPathComponent(playlistId).appendingPathComponent("posterImage.jpeg")
      try? fileClient.shouldCreateLibraryDirectory(.playlistCache, playlistId, PlaylistCache(
        playlist: playlist,
        groups: asset.groups,
        details: asset.details,
        repoModuleId: .init(repoId: asset.repoModuleId.repoId, moduleId: asset.repoModuleId.moduleId)
      ))
      if let image = asset.playlist.posterImage ?? asset.playlist.bannerImage, !image.isFileURL {
        let (data, _) = try await URLSession.shared.data(from: image)
      
        if let imageData = UIImage(data: data)?.jpegData(compressionQuality: 1) {
          try imageData.write(to: imageUrl)
        }
      }
    },
    remove: { type, playlist, episode in
      switch type {
        case .all:
          try fileClient.removePlaylistFromLibrary(.downloaded, playlist, episode)
          try fileClient.removePlaylistFromLibrary(.playlistCache, playlist, episode)
          break
        case .cache:
          try fileClient.removePlaylistFromLibrary(.playlistCache, playlist, episode)
          break
        case .download:
          try fileClient.removePlaylistFromLibrary(.downloaded, playlist, episode)
          break
      }
    },
    togglePause: { taskId in
      downloadManager.togglePauseDownload(taskId)
    },
    observeDownloading: {
      .init { continuation in
        let cancellable = Task.detached {
          var values = downloadManager.downloadingItems.compactMap {
            DownloadingItem(id: $0.metadata.link.url, percentComplete: $0.percentage, image: $0.playlist.posterImage ?? $0.playlist.bannerImage ?? URL(string: "")!, playlistName: $0.playlist.title ?? "", title: $0.episodeTitle, taskId: $0.taskId, status: $0.status)
          }
          continuation.yield(values)
          
          let notifications = NotificationCenter.default.notifications(
            named: .AssetDownloadProgress
          )
          for await notification in notifications {
            continuation.yield(downloadManager.downloadingItems.compactMap {
            DownloadingItem(id: $0.metadata.link.url, percentComplete: $0.percentage, image: $0.playlist.posterImage ?? $0.playlist.bannerImage ?? URL(string: "")!, playlistName: $0.playlist.title ?? "", title: $0.episodeTitle, taskId: $0.taskId, status: $0.status)
          })
          }
        }
        continuation.onTermination = { _ in
          cancellable.cancel()
        }
      }
    }
  )
}

// MARK: - OfflineDownloadManager

private class OfflineDownloadManager: NSObject {
  private var config: URLSessionConfiguration!
  private var downloadSession: AVAssetDownloadURLSession!
  public var downloadingItems: [OfflineManagerClient.DownloadingAsset] = []
  private let server = HTTPServer(port: 64390)
  
  @Dependency(\.fileClient) var fileClient

  override init() {
    super.init()
    Task {
      try await server.start()
    }
    config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
    downloadSession = AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
  }
  
  public func setupAssetDownload(_ asset: OfflineManagerClient.DownloadAsset) async throws {
    await initializeRoutes(asset)
    try await server.waitUntilListening()
    let options = [AVURLAssetAllowsCellularAccessKey: false]
    let libraryFileUrl = try fileClient.retrieveLibraryDirectory(root: .playlistCache)
    let playlist = asset.playlist
    let avAsset = AVURLAsset(url: URL(string: "http://localhost:64390/download.m3u?url=\(asset.episodeMetadata.link.url.absoluteString)")!, options: options)
    let preferredMediaSelection = try await avAsset.load(.preferredMediaSelection)
    
    guard let downloadTask = downloadSession.aggregateAssetDownloadTask(with: avAsset,
                                                                  mediaSelections: [preferredMediaSelection],
                                                                  assetTitle: asset.playlist.title ?? "Unknown Title",
                                                                  assetArtworkData: nil,
                                                                  options: nil) else {
      throw OfflineManagerClient.Error.failedToCreateDownloadTask
    }
    downloadingItems.append(.init(url: asset.episodeMetadata.link.url, playlist: playlist, episodeId: asset.episodeId, episodeTitle: asset.episodeTitle, metadata: asset.episodeMetadata, taskId: downloadTask.taskIdentifier, status: .downloading))

    let playlistId = playlist.id.rawValue.replacingOccurrences(of: "/", with: "\\")
    let imageUrl = libraryFileUrl.appendingPathComponent(playlistId).appendingPathComponent("posterImage.jpeg")
    try? fileClient.shouldCreateLibraryDirectory(.playlistCache, playlistId, PlaylistCache(
      playlist: playlist,
      groups: asset.groups,
      details: asset.details,
      repoModuleId: .init(repoId: asset.repoModuleId.repoId, moduleId: asset.repoModuleId.moduleId)
    ))
    
    let image = asset.playlist.posterImage ?? asset.playlist.bannerImage ?? URL(string: "")!
    let (data, _) = try await URLSession.shared.data(from: image)
    
    if let imageData = UIImage(data: data)?.jpegData(compressionQuality: 1) {
      try imageData.write(to: imageUrl)
    }
        
    downloadTask.resume()
    
    NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: nil)
  }
  
  func togglePauseDownload(_ taskId: Int) {
    downloadSession.getAllTasks { tasksArray in
      if let task = tasksArray.first(where: { $0.taskIdentifier == taskId }), let idx = self.downloadingItems.firstIndex(where: { $0.taskId == taskId }) {
        if (task.state == .suspended) {
          task.resume()
          self.downloadingItems[idx].status = .downloading
        } else if (task.state == .running) {
          task.suspend()
          self.downloadingItems[idx].status = .suspended
        }
      }
    }
  }
  
  func restorePendingDownloads() {
    downloadSession.getAllTasks { tasksArray in
      for task in tasksArray {
        guard let downloadTask = task as? AVAssetDownloadTask else { break }
        
        let _ = downloadTask.urlAsset
        downloadTask.resume()
      }
    }
  }
  
  public func deleteOfflineAsset() {
    do {
      let userDefaults = UserDefaults.standard
      if let assetPath = userDefaults.value(forKey: "assetPath") as? String {
        let baseURL = URL(fileURLWithPath: NSHomeDirectory())
        let assetURL = baseURL.appendingPathComponent(assetPath)
        try FileManager.default.removeItem(at: assetURL)
        userDefaults.removeObject(forKey: "assetPath")
      }
    } catch {
      print("An error occured deleting offline asset: \(error)")
    }
  }
  
}

extension OfflineDownloadManager {
  private func initializeRoutes(_ asset: OfflineManagerClient.DownloadAsset) async {
    await server.appendRoute("GET /download.m3u", handler: { req in
      let hlsSubtitleGroupID = "mochi-sub"
      
      func convertMainPlaylistToMultivariant(_ url: URL, _ subtitles: [Playlist.EpisodeServer.Subtitle]) -> String {
        // Build a multivariant playlist out of a single main playlist
        let subtitlesMediaStrings = subtitles.enumerated()
          .map(makeSubtitleTypes)
        
        return """
    #EXTM3U
    \(subtitlesMediaStrings.joined(separator: "\n"))
    #EXT-X-STREAM-INF:BANDWIDTH=640000\(!subtitles.isEmpty ? ",SUBTITLES=\"\(hlsSubtitleGroupID)\"": "")
    \(url.absoluteString)
    """
      }
      
      func makeSubtitleTypes(_ idx: Int, _ subtitle: Playlist.EpisodeServer.Subtitle) -> String {
        "#EXT-X-MEDIA:" + (
          [
            "TYPE": "SUBTITLES",
            "GROUP-ID": "\"\(hlsSubtitleGroupID)\"",
            "NAME": "\"\(subtitle.name)\"",
            "CHARACTERISTICS": "\"public.accessibility.transcribes-spoken-dialog\"",
            "DEFAULT": subtitle.default ? "YES" : "NO",
            "AUTOSELECT": subtitle.autoselect ? "YES" : "NO",
            "FORCED": "NO",
            "URI": "\"http://localhost:64390/subs.m3u8?url=\(subtitle.url.absoluteString)\"",
            "LANGUAGE": "\"\(subtitle.name)\""
          ] as OrderedDictionary
        )
        .map { "\($0.key)=\($0.value)" }
        .joined(separator: ",")
      }
      
      var path = req.path
      path.remove(at: req.path.startIndex)
      let m3u8 = convertMainPlaylistToMultivariant(asset.episodeMetadata.link.url, asset.episodeMetadata.subtitles)
      return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/vnd.apple.mpegurl"], body: m3u8.data(using: .utf8)!)
    })
    
    await server.appendRoute("GET /subs.m3u8", handler: { req in
      func setupSubM3U8(_ url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(for: .init(url: url))
        let vttString = String(data: data , encoding: .utf8)!
        
        let lastTimeStampString = (
          try? NSRegularExpression(pattern: "(?:(\\d+):)?(\\d+):([\\d\\.]+)")
            .matches(
              in: vttString,
              range: .init(location: 0, length: vttString.utf16.count)
            )
            .last
            .flatMap { Range($0.range, in: vttString) }
            .flatMap { String(vttString[$0]) }
        ) ?? "0.000"
        
        let duration = lastTimeStampString.components(separatedBy: ":").reversed()
          .compactMap { Double($0) }
          .enumerated()
          .map { pow(60.0, Double($0.offset)) * $0.element }
          .reduce(0, +)
        
        let m3u8Subtitle = """
      #EXTM3U
      #EXT-X-VERSION:3
      #EXT-X-MEDIA-SEQUENCE:1
      #EXT-X-PLAYLIST-TYPE:VOD
      #EXT-X-ALLOW-CACHE:NO
      #EXT-X-TARGETDURATION:\(Int(duration))
      #EXTINF:\(String(format: "%.3f", duration)), no desc
      \(url.absoluteString)
      #EXT-X-ENDLIST
      """
        
        return m3u8Subtitle
      }
      
      let idx = URL(string: req.query.first!.value)!
      let m3u8 = try await setupSubM3U8(idx)
      return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/vnd.apple.mpegurl"], body: m3u8.data(using: .utf8)!)
    })
  }
}

extension OfflineDownloadManager: AVAssetDownloadDelegate {
  func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                  didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                  timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {
    let percentComplete = loadedTimeRanges.reduce(0) { (rc, value) -> Double in
      let loadedTimeRange: CMTimeRange = value.timeRangeValue
      return rc + Double((loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds))
    }
    guard let idx = downloadingItems.firstIndex(where: { $0.metadata.link.url.absoluteString == aggregateAssetDownloadTask.urlAsset.url.absoluteString.components(separatedBy: "url=").last }) else {
      return
    }
    downloadingItems[idx].percentage = percentComplete
//    debugPrint(percentComplete)
    let params: [String : Any] = ["percent": percentComplete, "assetUrl": aggregateAssetDownloadTask.urlAsset.url]
    NotificationCenter.default.post(name: .AssetDownloadProgress, object: nil, userInfo: params)
  }
  
  func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, willDownloadTo location: URL) {
    guard let idx = downloadingItems.firstIndex(where: {
    return $0.metadata.link.url.absoluteString == aggregateAssetDownloadTask.urlAsset.url.absoluteString.components(separatedBy: "url=").last
    }) else {
      return
    }
    downloadingItems[idx].location = location
  }
  
  func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, didCompleteFor mediaSelection: AVMediaSelection) {
    if let downloadedAsset = downloadingItems.first(where: { $0.metadata.link.url.absoluteString == aggregateAssetDownloadTask.urlAsset.url.absoluteString.components(separatedBy: "url=").last }) {
      guard let outputURL = try? fileClient.retrieveLibraryDirectory(root: .downloaded, playlist: downloadedAsset.playlist.id.rawValue, episode: downloadedAsset.episodeId.rawValue) else {
        return
      }
      do {
        try saveVideo(asset: downloadedAsset, location: downloadedAsset.location!)
      } catch {
        debugPrint(error)
      }
    }
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    debugPrint("Task completed: \(task), error: \(String(describing: error))")
    
    guard let task = task as? AVAggregateAssetDownloadTask else { return }
    guard error == nil else {
      if let idx = downloadingItems.firstIndex(where: { $0.url.absoluteString == task.urlAsset.url.absoluteString.components(separatedBy: "url=").last }) {
        downloadingItems[idx].status = .finished
      }
      return
    }
  }
}

extension OfflineDownloadManager {
  private func saveVideo(asset: OfflineManagerClient.DownloadingAsset, location: URL) throws {
    let outputURL = try fileClient.retrieveLibraryDirectory(root: .downloaded, playlist: asset.playlist.id.rawValue, episode: asset.episodeId.rawValue)
    debugPrint("File saved to: \(outputURL)")
    if (FileManager.default.fileExists(atPath: outputURL.path)) {
      try FileManager.default.removeItem(at: outputURL.appendingPathComponent("data").appendingPathExtension("movpkg"))
    }
    try fileClient.shouldCreateLibraryDirectory(
      .downloaded,
      outputURL.pathComponents.suffix(2).joined(separator: "/"),
      EpisodeMetadata(
        link: asset.metadata.link,
        source: Playlist.EpisodeSource(id: asset.metadata.source.id, displayName: asset.metadata.source.displayName, description: asset.metadata.source.description, servers: [asset.metadata.server]),
        subtitles: asset.metadata.subtitles,
        server: Playlist.EpisodeServer(id: asset.metadata.server.id, displayName: asset.metadata.server.displayName, description: asset.metadata.server.description),
        skipTimes: asset.metadata.skipTimes
      )
    )
    try FileManager.default.moveItem(at: location, to: outputURL.appendingPathComponent("data").appendingPathExtension("movpkg"))
  }
}

extension Notification.Name {
    /// Notification for when download progress has changed.
    static let AssetDownloadProgress = Notification.Name(rawValue: "AssetDownloadProgressNotification")
    
    /// Notification for when the download state of an Asset has changed.
    static let AssetDownloadStateChanged = Notification.Name(rawValue: "AssetDownloadStateChangedNotification")
    
    /// Notification for when AssetPersistenceManager has completely restored its state.
    static let AssetPersistenceManagerDidRestoreState = Notification.Name(rawValue: "AssetPersistenceManagerDidRestoreStateNotification")
}
