//
//  View+ReadSize.swift
//
//
//  Created by MochiTeam on 4/21/23.
//
//

import Foundation
import SwiftUI

// MARK: - SizeInset

public struct SizeInset {
  public let size: CGSize
  public let safeAreaInsets: EdgeInsets

  public var horizontal: CGFloat {
    size.width + safeAreaInsets.leading + safeAreaInsets.trailing
  }

  public var vertical: CGFloat {
    size.height + safeAreaInsets.top + safeAreaInsets.bottom
  }

  public static var zero: Self {
    .init(size: .zero, safeAreaInsets: .init())
  }
}

// MARK: Equatable

extension SizeInset: Equatable {}

// MARK: Sendable

extension SizeInset: Sendable {}

extension View {
  @MainActor
  public func readSize(_ callback: @escaping (SizeInset) -> Void) -> some View {
    background(
      GeometryReader { geometryProxy in
        Color.clear
          .onAppear {
            callback(
              .init(
                size: geometryProxy.size,
                safeAreaInsets: geometryProxy.safeAreaInsets
              )
            )
          }
        #if os(iOS)
          .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            callback(
              .init(
                size: geometryProxy.size,
                safeAreaInsets: geometryProxy.safeAreaInsets
              )
            )
          }
        #endif
          .onChange(of: geometryProxy.size) { newValue in
            callback(
              .init(
                size: newValue,
                safeAreaInsets: geometryProxy.safeAreaInsets
              )
            )
          }
      }
    )
  }
}

// MARK: - ReadableSizeView

@MainActor
public struct ReadableSizeView<Content: View>: View {
  @MainActor
  public init(
    @ViewBuilder content: @escaping (CGSize) -> Content
  ) {
    self.content = content
  }

  let content: (CGSize) -> Content
  @State var size = CGSize.zero

  @MainActor public var body: some View {
    content(size)
      .readSize { size = $0.size }
  }
}
