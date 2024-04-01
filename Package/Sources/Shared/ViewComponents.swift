//
//  ViewComponents.swift
//
//
//  Created by MochiTeam on 10/5/23.
//
//

import Foundation

struct ViewComponents: _Shared {
    var dependencies: any Dependencies {
        SharedModels()
        ComposableArchitecture()
        NukeUI()
    }
}
