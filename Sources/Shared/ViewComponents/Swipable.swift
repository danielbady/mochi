//
//  Swipable.swift
//
//
//  Created by MochiTeam on 6/27/23.
//
//

import Foundation
import SwiftUI

// MARK: - SwipeableModifier

private struct SwipeableModifier: ViewModifier {
  let showForced: Bool
  let animation: Animation?

  @State private var dismissed = false

  func body(content: Content) -> some View {
    if !dismissed || showForced {
      content
        .highPriorityGesture(
          DragGesture()
            .onEnded { _ in
              withAnimation(animation) {
                dismissed = true
              }
            }
        )
    }
  }
}

extension View {
  public func swipeable(_ showForced: Bool = false, _ animation: Animation? = nil) -> some View {
    modifier(SwipeableModifier(showForced: showForced, animation: animation))
  }
}
