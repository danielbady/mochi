//
//  MochiPlatforms.swift
//
//
//  Created by MochiTeam on 10/4/23.
//
//

import Foundation

struct MochiPlatforms: PlatformSet {
    var body: any SupportedPlatforms {
        SupportedPlatform.macOS(.v12)
        SupportedPlatform.iOS(.v15)
    }
}
