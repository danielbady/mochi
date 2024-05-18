//
//  DownloadQueue.swift
//  
//
//  Created by DeNeRr on 16.05.2024.
//

import Foundation

struct DownloadQueue: _Feature {
  var dependencies: any Dependencies {
    Architecture()
    FileClient()
    ViewComponents()
    ComposableArchitecture()
    OfflineManagerClient()
    Styling()
  }
}
