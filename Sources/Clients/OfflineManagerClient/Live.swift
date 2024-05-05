//
//  Live.swift
//
//
//  Created by DeNeRr on 06.04.2024.
//

//import Dependencies
//import Foundation
//import FileClient
//import AVFoundation
//import UIKit
//import SharedModels
//import DatabaseClient
//import OrderedCollections
//
//// MARK: - OfflineManagerClient + DependencyKey
//
//extension OfflineManagerClient: DependencyKey {
//  private static let downloadManager = OfflineDownloadManager()
//  
//  public static let liveValue = Self(
//    download: { asset in
//      try? await downloadManager.setupAssetDownload(asset)
//    }
//  )
//}
//
//// MARK: - OfflineDownloadManager
//
//private class OfflineDownloadManager: NSObject {
//  enum Error: Swift.Error {
//    case M3U8Invalid
//    case VTTInvalid
//  }
//
//  private var config: URLSessionConfiguration!
//  private var downloadSession: AVAssetDownloadURLSession!
//  private var downloadQueue: Set<OfflineManagerClient.DownloadingAsset> = []
//  
//  @Dependency(\.fileClient) var fileClient
//
//  override init() {
//    super.init()
//    config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
//    downloadSession = AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
//  }
//  
//  private static let hlsSubtitlesScheme = "mochi-hls-subtitles"
//  private static let hlsSubtitleGroupID = "mochi-sub"
//  
//  private func convertMainPlaylistToMultivariant(_ url: URL, _ subtitles: [Playlist.EpisodeServer.Subtitle]) -> String {
//    // Build a multivariant playlist out of a single main playlist
//    let subtitlesMediaStrings = subtitles.enumerated()
//      .map(makeSubtitleTypes)
//
//    return """
//    #EXTM3U
//    \(subtitlesMediaStrings.joined(separator: "\n"))
//    #EXT-X-STREAM-INF:BANDWIDTH=6400000,CODECS="mp4a.40.2,avc1.4d401e",SUBTITLES="\(Self.hlsSubtitleGroupID)"
//    \(url.absoluteString)
//    """
//  }
//
//  private func makeSubtitleTypes(_ idx: Int, _ subtitle: Playlist.EpisodeServer.Subtitle) -> String {
//    "#EXT-X-MEDIA:" + (
//      [
//        "TYPE": "SUBTITLES",
//        "GROUP-ID": "\"\(Self.hlsSubtitleGroupID)\"",
//        "NAME": "\"\(subtitle.name)\"",
//        "CHARACTERISTICS": "\"public.accessibility.transcribes-spoken-dialog\"",
//        "DEFAULT": subtitle.default ? "YES" : "NO",
//        "AUTOSELECT": subtitle.autoselect ? "YES" : "NO",
//        "FORCED": "NO",
//        "URI": "\"\(subtitle.url.absoluteString)\"",
//        "LANGUAGE": "\"\(subtitle.name)\""
//      ] as OrderedDictionary
//    )
//    .map { "\($0.key)=\($0.value)" }
//    .joined(separator: ",")
//  }
//  
//  private func parseMainMultiVariantPlaylist(_ m3u8String: String, _ subtitles: [Playlist.EpisodeServer.Subtitle]) -> String {
//    var lines = m3u8String.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
//    var lastPositionMedia: Int?
//    var firstPositionInf = 1
//
//    for (idx, line) in lines.enumerated() {
//      if line.hasPrefix("#EXT-X-STREAM-INF") {
//        firstPositionInf = idx
//        break
//      } else if line.hasPrefix("#EXT-X-MEDIA") {
//        lastPositionMedia = idx + 1
//      }
//    }
//
//    var subtitlePosition = lastPositionMedia ?? firstPositionInf
//
//    for (idx, subtitle) in subtitles.enumerated() {
//      let m3u8SubtitlesString = makeSubtitleTypes(idx, subtitle)
//      if subtitlePosition <= lines.endIndex {
//        lines.insert(m3u8SubtitlesString, at: subtitlePosition)
//      } else {
//        lines.append(m3u8SubtitlesString)
//      }
//      subtitlePosition += 1
//    }
//
//    for (idx, line) in lines.enumerated() where line.contains("#EXT-X-STREAM-INF") {
//      lines[idx] = line + "," + "SUBTITLES=\"\(Self.hlsSubtitleGroupID)\""
//    }
//
//    return lines.joined(separator: "\n")
//  }
//  
//  public func setupAssetDownload(_ asset: OfflineManagerClient.Asset) async throws {
//    let (data, _) = try await URLSession.shared.data(from: asset.episodeMetadata.link.url)
//    guard let string = String(data: data, encoding: .utf8) else {
//      throw Error.M3U8Invalid
//    }
//    let playlistData: String
//    if string.contains("#EXT-X-STREAM-INF") {
//      playlistData = parseMainMultiVariantPlaylist(string, asset.episodeMetadata.subtitles)
//    } else {
//      playlistData = convertMainPlaylistToMultivariant(asset.episodeMetadata.link.url, asset.episodeMetadata.subtitles)
//    }
//    
//    let options = [AVURLAssetAllowsCellularAccessKey: false]
//    let libraryFileUrl = try fileClient.retrieveLibraryDirectory(root: .playlistCache)
//    let outputURL = try fileClient.retrieveLibraryDirectory(root: .downloaded, playlist: asset.playlist.id.rawValue, episode: asset.episodeId.rawValue)
//    try? fileClient.shouldCreateLibraryDirectory(
//      .downloaded,
//      outputURL.pathComponents.suffix(2).joined(separator: "/"),
//      EpisodeMetadata(
//        link: asset.episodeMetadata.link,
//        source: Playlist.EpisodeSource(id: asset.episodeMetadata.source.id, displayName: asset.episodeMetadata.source.displayName, description: asset.episodeMetadata.source.description, servers: [asset.episodeMetadata.server]),
//        subtitles: asset.episodeMetadata.subtitles,
//        server: Playlist.EpisodeServer(id: asset.episodeMetadata.server.id, displayName: asset.episodeMetadata.server.displayName, description: asset.episodeMetadata.server.description),
//        skipTimes: asset.episodeMetadata.skipTimes
//      )
//    )
//    let avAsset = AVURLAsset(url: URL(string:"data:application/x-mpegURL;charset=utf-8,%23EXTM3U%0A%0A%23EXT-X-MEDIA%3ATYPE%3DAUDIO%2CGROUP-ID%3D%22bipbop_audio%22%2CLANGUAGE%3D%22eng%22%2CNAME%3D%22BipBop%20Audio%201%22%2CAUTOSELECT%3DYES%2CDEFAULT%3DYES%0A%23EXT-X-MEDIA%3ATYPE%3DAUDIO%2CGROUP-ID%3D%22bipbop_audio%22%2CLANGUAGE%3D%22eng%22%2CNAME%3D%22BipBop%20Audio%202%22%2CAUTOSELECT%3DNO%2CDEFAULT%3DNO%2CURI%3D%22https%3A%2F%2Fd2zihajmogu5jn.cloudfront.net%2Fbipbop-advanced%2Falternate_audio_aac_sinewave%2Fprog_index.m3u8%22%0A%0A%23EXT-X-MEDIA%3ATYPE%3DSUBTITLES%2CGROUP-ID%3D%22subs%22%2CNAME%3D%22English%22%2CDEFAULT%3DYES%2CAUTOSELECT%3DYES%2CFORCED%3DNO%2CLANGUAGE%3D%22en%22%2CCHARACTERISTICS%3D%22public.accessibility.transcribes-spoken-dialog%2C%20public.accessibility.describes-music-and-sound%22%2CURI%3D%22https%3A%2F%2Fd2zihajmogu5jn.cloudfront.net%2Fbipbop-advanced%2Fsubtitles%2Feng%2Fprog_index.m3u8%22%0A%0A%23EXT-X-STREAM-INF%3ABANDWIDTH%3D263851%2CCODECS%3D%22mp4a.40.2%2C%20avc1.4d400d%22%2CRESOLUTION%3D416x234%2CAUDIO%3D%22bipbop_audio%22%2CSUBTITLES%3D%22subs%22%0Ahttps%3A%2F%2Fd2zihajmogu5jn.cloudfront.net%2Fbipbop-advanced%2Fgear1%2Fprog_index.m3u8")!)
//    
//    
//    
////    let downloadTask = downloadSession.makeAssetDownloadTask(asset: avAsset,
////                                                             assetTitle: asset.playlist.title ?? "Unknown Title",
////                                                             assetArtworkData: nil,
////                                                             options: nil)
//    let preferredMediaSelection = try await avAsset.load(.preferredMediaSelection)
//    
//    let downloadTask = downloadSession.aggregateAssetDownloadTask(with: avAsset,
//                                                                  mediaSelections: [preferredMediaSelection],
//                                                                  assetTitle: asset.playlist.title ?? "Unknown Title",
//                                                                  assetArtworkData: nil,
//                                                                  options: nil)
//    
//    let playlist = asset.playlist
//    let playlistId = playlist.id.rawValue.replacingOccurrences(of: "/", with: "\\")
//    let imageUrl = libraryFileUrl.appendingPathComponent(playlistId).appendingPathComponent("posterImage.jpeg")
//    try? fileClient.shouldCreateLibraryDirectory(.playlistCache, playlistId, PlaylistCache(
//      playlist: playlist,
//      groups: asset.groups,
//      details: asset.details,
//      repoModuleId: .init(repoId: asset.repoModuleId.repoId, moduleId: asset.repoModuleId.moduleId)
//    ))
//    
//    let image = asset.playlist.posterImage ?? asset.playlist.bannerImage ?? URL(string: "")!
//    let (imageData, _) = try await URLSession.shared.data(from: image)
//    
//    if let imageData = UIImage(data: imageData)?.jpegData(compressionQuality: 1) {
//      try imageData.write(to: imageUrl)
//    }
//        
//    downloadTask?.resume()
//    downloadQueue.insert(.init(url: asset.episodeMetadata.link.url, playlistId: playlist.id, episodeId: asset.episodeId, metadata: asset.episodeMetadata))
//    NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: nil)
//  }
//  
//  func restorePendingDownloads() {
//    downloadSession.getAllTasks { tasksArray in
//      for task in tasksArray {
//        guard let downloadTask = task as? AVAssetDownloadTask else { break }
//        
//        let asset = downloadTask.urlAsset
//        downloadTask.resume()
//      }
//    }
//  }
//  
//  func playOfflineAsset() -> AVURLAsset? {
//    guard let assetPath = UserDefaults.standard.value(forKey: "assetPath") as? String else {
//      return nil
//    }
//    let baseURL = URL(fileURLWithPath: NSHomeDirectory())
//    let assetURL = baseURL.appendingPathComponent(assetPath)
//    let asset = AVURLAsset(url: assetURL)
//    if let cache = asset.assetCache, cache.isPlayableOffline {
//      return asset
//    } else {
//      return nil
//    }
//  }
//  
//  func getPath() -> String {
//    return UserDefaults.standard.value(forKey: "assetPath") as? String ?? ""
//  }
//  
//  public func deleteOfflineAsset() {
//    do {
//      let userDefaults = UserDefaults.standard
//      if let assetPath = userDefaults.value(forKey: "assetPath") as? String {
//        let baseURL = URL(fileURLWithPath: NSHomeDirectory())
//        let assetURL = baseURL.appendingPathComponent(assetPath)
//        try FileManager.default.removeItem(at: assetURL)
//        userDefaults.removeObject(forKey: "assetPath")
//      }
//    } catch {
//      print("An error occured deleting offline asset: \(error)")
//    }
//  }
//  
//  public func deleteDownloadedVideo(atPath path: String) {
//    do {
//      let baseURL = URL(fileURLWithPath: NSHomeDirectory())
//      let assetURL = baseURL.appendingPathComponent(path)
//      try FileManager.default.removeItem(at: assetURL)
//      
//      if var downloadedPaths = UserDefaults.standard.array(forKey: "DownloadedVideoPaths") as? [String],
//         let index = downloadedPaths.firstIndex(of: path) {
//        downloadedPaths.remove(at: index)
//        UserDefaults.standard.set(downloadedPaths, forKey: "DownloadedVideoPaths")
//      }
//      
////      NotificationCenter.default.post(name: .didDeleteVideo, object: nil)
//    } catch {
//      print("An error occurred deleting offline asset: \(error)")
//    }
//  }
//}
//
//extension OfflineDownloadManager: AVAssetDownloadDelegate {
//
//
//  // 1. Tells the delegate the location this asset will be downloaded to.
//  func urlSession(_ session: URLSession,
//                  aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
//                  willDownloadTo location: URL) {
//                  debugPrint("willDownloadTo")
//                  UserDefaults.standard.set(location.absoluteString, forKey: "test_location")
//  }
//  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
//        debugPrint("didCompleteWithError")
//  }
//  
//  // 2. Report progress updates for the aggregate download task
//  func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
//                  didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue],
//                  timeRangeExpectedToLoad: CMTimeRange, for mediaSelection: AVMediaSelection) {
//    
//    let percentComplete = loadedTimeRanges.reduce(0) { (rc, value) -> Float in
//      let loadedTimeRange: CMTimeRange = value.timeRangeValue
//      return rc + Float((loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds))
//    }
//    debugPrint(percentComplete)
//    let params = ["percent": percentComplete, "assetUrl": aggregateAssetDownloadTask.urlAsset.url] as [String : Any]
//    NotificationCenter.default.post(name: .AssetDownloadProgress, object: nil, userInfo: params)
//
//    if (percentComplete >= 1) {
//      NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: nil)
//      let location = UserDefaults.standard.string(forKey: "test_location")!
//      debugPrint(FileManager.default.fileExists(atPath: URL(string: location)!.path))
//      if let downloadedAsset = downloadQueue.first {
//        try? saveVideo(asset: downloadedAsset, location: URL(string: location)!)
//      }
//    }
//  }
//  
//  // 3. Tells the delegate that the task finished transferring data, either successfully or with an error
//  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
//    debugPrint("DOWNLOAD FINISHED")
//  }
//  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
//        var percentComplete = 0.0
//        
//        for value in loadedTimeRanges {
//            let loadedTimeRange = value.timeRangeValue
//            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
//        }
//        if (percentComplete >= 1) {
//          NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: nil)
//        }
//        percentComplete *= 100
//        
//        debugPrint("Progress \( assetDownloadTask) \(percentComplete)")
//        let params = ["percent": percentComplete, "assetUrl": assetDownloadTask.urlAsset.url] as [String : Any]
//        NotificationCenter.default.post(name: .AssetDownloadProgress, object: nil, userInfo: params)
//    }
//    
//  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
//    if let downloadedAsset = downloadQueue.first(where: { $0.url == assetDownloadTask.urlAsset.url }) {
//      try? saveVideo(asset: downloadedAsset, location: location)
//    }
//  }
//  
//  func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
//    debugPrint("didFinishCollecting")
//  }
//  
//  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
//    debugPrint("didBecomeInvalidWithError")
//  }
//  
//  func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
//    debugPrint("needNewBodyStream")
//  }
//  
//  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didResolve resolvedMediaSelection: AVMediaSelection) {
//    debugPrint("didResolve")
//  }
//  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
//    debugPrint("forBackgroundURLSession")
//  }
//  func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, didCompleteFor mediaSelection: AVMediaSelection) {
//    debugPrint("mediaSelection")
//  }
//  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, willDownloadVariants variants: [AVAssetVariant]) {
//    debugPrint("variants")
//  }
//  
////  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
////    debugPrint("Task completed: \(task), error: \(String(describing: error))")
////    
////    guard error == nil else { return }
////    guard let task = task as? AVAggregateAssetDownloadTask else { return }
////    print("DOWNLOAD: FINISHED")
////  }
//}
//
//extension OfflineDownloadManager {
//  private func saveVideo(asset: OfflineManagerClient.DownloadingAsset, location: URL) throws {
//    let outputURL = try fileClient.retrieveLibraryDirectory(root: .downloaded, playlist: asset.playlistId.rawValue, episode: asset.episodeId.rawValue)
//    debugPrint("File saved to: \(outputURL)")
//    try FileManager.default.moveItem(at: location, to: outputURL.appendingPathComponent("data.movpkg"))
//  }
//}
//
//extension Notification.Name {
//    /// Notification for when download progress has changed.
//    static let AssetDownloadProgress = Notification.Name(rawValue: "AssetDownloadProgressNotification")
//    
//    /// Notification for when the download state of an Asset has changed.
//    static let AssetDownloadStateChanged = Notification.Name(rawValue: "AssetDownloadStateChangedNotification")
//    
//    /// Notification for when AssetPersistenceManager has completely restored its state.
//    static let AssetPersistenceManagerDidRestoreState = Notification.Name(rawValue: "AssetPersistenceManagerDidRestoreStateNotification")
//}


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

extension Sequence {
    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed in order, by waiting for
    /// each call to complete before proceeding with the next one. If
    /// any of the closure calls throw an error, then the iteration
    /// will be terminated and the error rethrown.
    ///
    /// - parameter operation: The closure to run for each element.
    /// - throws: Rethrows any error thrown by the passed closure.
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }

    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter operation: The closure to run for each element.
    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        _ operation: @escaping (Element) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask(priority: priority) {
                    await operation(element)
                }
            }
        }
    }

    /// Run an async closure for each element within the sequence.
    ///
    /// The closure calls will be performed concurrently, but the call
    /// to this function won't return until all of the closure calls
    /// have completed. If any of the closure calls throw an error,
    /// then the first error will be rethrown once all closure calls have
    /// completed.
    ///
    /// - parameter priority: Any specific `TaskPriority` to assign to
    ///   the async tasks that will perform the closure calls. The
    ///   default is `nil` (meaning that the system picks a priority).
    /// - parameter operation: The closure to run for each element.
    /// - throws: Rethrows any error thrown by the passed closure.
    func concurrentForEach(
        withPriority priority: TaskPriority? = nil,
        _ operation: @escaping (Element) async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for element in self {
                group.addTask(priority: priority) {
                    try await operation(element)
                }
            }

            // Propagate any errors thrown by the group's tasks:
            for try await _ in group {}
        }
    }
}


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
    }
  )
}

// MARK: - OfflineDownloadManager

private class OfflineDownloadManager: NSObject {
  private var config: URLSessionConfiguration!
  private var downloadSession: AVAssetDownloadURLSession!
  private var downloadQueue: Set<OfflineManagerClient.DownloadingAsset> = []
  
  @Dependency(\.fileClient) var fileClient

  override init() {
    super.init()
    config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
    downloadSession = AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
  }
  
  public func setupAssetDownload(_ asset: OfflineManagerClient.DownloadAsset) async throws {
    let options = [AVURLAssetAllowsCellularAccessKey: false]
    let avAsset = AVURLAsset(url: asset.episodeMetadata.link.url, options: options)
    let libraryFileUrl = try fileClient.retrieveLibraryDirectory(root: .playlistCache)
    
    let downloadTask = downloadSession.makeAssetDownloadTask(asset: avAsset,
                                                             assetTitle: asset.playlist.title ?? "Unknown Title",
                                                             assetArtworkData: nil,
                                                             options: [AVAssetDownloadTaskPrefersHDRKey: false, AVAssetDownloadTaskPrefersLosslessAudioKey: false])

    let playlist = asset.playlist
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
        
    let outputURL = try fileClient.retrieveLibraryDirectory(root: .downloaded, playlist: asset.playlist.id.rawValue, episode: asset.episodeId.rawValue)
    try? fileClient.shouldCreateLibraryDirectory(
      .downloaded,
      outputURL.pathComponents.suffix(2).joined(separator: "/"),
      EpisodeMetadata(
        link: asset.episodeMetadata.link,
        source: Playlist.EpisodeSource(id: asset.episodeMetadata.source.id, displayName: asset.episodeMetadata.source.displayName, description: asset.episodeMetadata.source.description, servers: [asset.episodeMetadata.server]),
        subtitles: asset.episodeMetadata.subtitles,
        server: Playlist.EpisodeServer(id: asset.episodeMetadata.server.id, displayName: asset.episodeMetadata.server.displayName, description: asset.episodeMetadata.server.description),
        skipTimes: asset.episodeMetadata.skipTimes
      )
    )
    await asset.episodeMetadata.subtitles.concurrentForEach {
      if let data = try? await URLSession.shared.data(from: $0.url) {
        let fileName = $0.id.rawValue.lastPathComponent
        try? data.0.write(to: outputURL.appendingPathComponent(fileName))
      }
    }
    downloadTask?.resume()
    downloadQueue.insert(.init(url: asset.episodeMetadata.link.url, playlistId: playlist.id, episodeId: asset.episodeId, metadata: asset.episodeMetadata))
    
    NotificationCenter.default.post(name: .AssetDownloadStateChanged, object: nil, userInfo: nil)
  }
  
  func restorePendingDownloads() {
    downloadSession.getAllTasks { tasksArray in
      for task in tasksArray {
        guard let downloadTask = task as? AVAssetDownloadTask else { break }
        
        let asset = downloadTask.urlAsset
        downloadTask.resume()
      }
    }
  }
  
  func playOfflineAsset() -> AVURLAsset? {
    guard let assetPath = UserDefaults.standard.value(forKey: "assetPath") as? String else {
      return nil
    }
    let baseURL = URL(fileURLWithPath: NSHomeDirectory())
    let assetURL = baseURL.appendingPathComponent(assetPath)
    let asset = AVURLAsset(url: assetURL)
    if let cache = asset.assetCache, cache.isPlayableOffline {
      return asset
    } else {
      return nil
    }
  }
  
  func getPath() -> String {
    return UserDefaults.standard.value(forKey: "assetPath") as? String ?? ""
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
  
  public func deleteDownloadedVideo(atPath path: String) {
    do {
      let baseURL = URL(fileURLWithPath: NSHomeDirectory())
      let assetURL = baseURL.appendingPathComponent(path)
      try FileManager.default.removeItem(at: assetURL)
      
      if var downloadedPaths = UserDefaults.standard.array(forKey: "DownloadedVideoPaths") as? [String],
         let index = downloadedPaths.firstIndex(of: path) {
        downloadedPaths.remove(at: index)
        UserDefaults.standard.set(downloadedPaths, forKey: "DownloadedVideoPaths")
      }
      
//      NotificationCenter.default.post(name: .didDeleteVideo, object: nil)
    } catch {
      print("An error occurred deleting offline asset: \(error)")
    }
  }
}

extension OfflineDownloadManager: AVAssetDownloadDelegate {
  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
    var percentComplete = 0.0
    
    for value in loadedTimeRanges {
      let loadedTimeRange = value.timeRangeValue
      percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
    }
    percentComplete *= 100
    
    debugPrint("Progress \( assetDownloadTask) \(percentComplete)")
    
    let params = ["percent": percentComplete, "assetUrl": assetDownloadTask.urlAsset.url] as [String : Any]
    NotificationCenter.default.post(name: .AssetDownloadProgress, object: nil, userInfo: params)
  }
  
  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
    if let downloadedAsset = downloadQueue.first(where: { $0.url == assetDownloadTask.urlAsset.url }) {
      try? saveVideo(asset: downloadedAsset, location: location)
    }
  }
  
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    debugPrint("Download finished: \(location.absoluteString)")
  }
  
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    debugPrint("Task completed: \(task), error: \(String(describing: error))")
    
    guard error == nil else { return }
    guard let task = task as? AVAssetDownloadTask else { return }
    print("DOWNLOAD: FINISHED")
  }
}

extension OfflineDownloadManager {
  private func saveVideo(asset: OfflineManagerClient.DownloadingAsset, location: URL) throws {
    let outputURL = try fileClient.retrieveLibraryDirectory(root: .downloaded, playlist: asset.playlistId.rawValue, episode: asset.episodeId.rawValue)
    debugPrint("File saved to: \(outputURL)")
    try FileManager.default.moveItem(at: location, to: outputURL.appendingPathComponent("data.movpkg"))
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
