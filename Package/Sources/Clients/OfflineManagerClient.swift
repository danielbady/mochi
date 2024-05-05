//
//  OfflineManagerClient.swift
//
//
//  Created by DeNeRr on 06.04.2024.
//

import Foundation

struct OfflineManagerClient: _Client {
  var dependencies: any Dependencies {
    FileClient()
    SharedModels()
    ComposableArchitecture()
  }
}
