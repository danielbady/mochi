//
//  DownloadFeature.swift
//
//
//  Created by Muhammad Shah on 03/04/2024.
//

import Foundation
import SwiftUI
import AVKit

class DownloadManager: NSObject {
    static let shared = DownloadManager()
    private var config: URLSessionConfiguration!
    private var downloadSession: AVAssetDownloadURLSession!
    
    private override init() {
        super.init()
        config = URLSessionConfiguration.background(withIdentifier: "\(Bundle.main.bundleIdentifier!).background")
        downloadSession = AVAssetDownloadURLSession(configuration: config, assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
    }
    
    func setupAssetDownload(_ url: URL) {
        let options = [AVURLAssetAllowsCellularAccessKey: false]
        let asset = AVURLAsset(url: url, options: options)
        
        let downloadTask = downloadSession.makeAssetDownloadTask(asset: asset,
                                                                 assetTitle: "Test Download",
                                                                 assetArtworkData: nil,
                                                                 options: nil)
        
        downloadTask?.resume()
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
    
    func deleteOfflineAsset() {
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
    
    func deleteDownloadedVideo(atPath path: String) {
        do {
            let baseURL = URL(fileURLWithPath: NSHomeDirectory())
            let assetURL = baseURL.appendingPathComponent(path)
            try FileManager.default.removeItem(at: assetURL)
            
            if var downloadedPaths = UserDefaults.standard.array(forKey: "DownloadedVideoPaths") as? [String],
               let index = downloadedPaths.firstIndex(of: path) {
                downloadedPaths.remove(at: index)
                UserDefaults.standard.set(downloadedPaths, forKey: "DownloadedVideoPaths")
            }
            
            NotificationCenter.default.post(name: .didDeleteVideo, object: nil)
        } catch {
            print("An error occurred deleting offline asset: \(error)")
        }
    }
}

extension DownloadManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        var percentComplete = 0.0
        
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        percentComplete *= 100
        
        debugPrint("Progress \( assetDownloadTask) \(percentComplete)")
        
        let params = ["percent": percentComplete]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "completion"), object: nil, userInfo: params)
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        UserDefaults.standard.set(location.relativePath, forKey: "assetPath")
        // Add the downloaded video path to the list
        if var downloadedPaths = UserDefaults.standard.array(forKey: "DownloadedVideoPaths") as? [String] {
            downloadedPaths.append(location.relativePath)
            UserDefaults.standard.set(downloadedPaths, forKey: "DownloadedVideoPaths")
        } else {
            UserDefaults.standard.set([location.relativePath], forKey: "DownloadedVideoPaths")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        debugPrint("Download finished: \(location)")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        debugPrint("Task completed: \(task), error: \(String(describing: error))")
        
        guard error == nil else { return }
        guard let task = task as? AVAssetDownloadTask else { return }
        
        print("DOWNLOAD: FINISHED")
    }
}
