//
//  _Macro.swift
//
//
//  Created by MochiTeam on 10/27/23.
//
//

import Foundation

// MARK: - _Macro

protocol _Macro: Macro {}

extension _Macro {
    var path: String? {
        "Sources/Macros/\(name)"
    }
}
