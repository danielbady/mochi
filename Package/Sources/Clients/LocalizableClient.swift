//
//  LocalizableClient.swift
//
//
//  Created by MochiTeam on 12/1/23.
//
//

import Foundation

struct LocalizableClient: _Client {
    var dependencies: any Dependencies {
        ComposableArchitecture()
    }

    var resources: [Resource] {
        Resource.process("Resources")
    }
}
