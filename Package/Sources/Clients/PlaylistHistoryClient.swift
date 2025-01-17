//
//  PlaylistHistoryClient.swift
//
//
//  Created by MochiTeam on 29.01.2024.
//

import Foundation

struct PlaylistHistoryClient: _Client {
    var dependencies: any Dependencies {
        DatabaseClient()
        SharedModels()
        Semaphore()
        Tagged()
        ComposableArchitecture()
    }
}
