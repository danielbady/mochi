//
//  InsetValue.swift
//
//
//  Created by MochiTeam on 4/18/23.
//
//

import Combine
import ComposableArchitecture
import Foundation
import SwiftUI

// MARK: - InsetableValues

public class InsetableValues: @unchecked Sendable, ObservableObject {
  static var _current = InsetableValues()

  @Published var values = [ObjectIdentifier: CGSize]()

  private init() {}

  public subscript<K: InsetableKey>(key: K.Type) -> CGSize {
    get { values[ObjectIdentifier(key)] ?? K.defaultValue }
    set { values[ObjectIdentifier(key)] = newValue }
  }
}

// MARK: - InsetableKey

public protocol InsetableKey {
  static var defaultValue: CGSize { get }
}

// MARK: - InsetValue

@propertyWrapper
public struct InsetValue: @unchecked Sendable, DynamicProperty {
  @ObservedObject var values = InsetableValues._current

  private let keyPath: KeyPath<InsetableValues, CGSize>

  public init(_ keyPath: KeyPath<InsetableValues, CGSize>) {
    self.keyPath = keyPath
  }

  public var wrappedValue: CGSize {
    InsetableValues._current[keyPath: keyPath]
  }

  public var projectedValue: Self {
    get { self }
    set { self = newValue }
  }
}

extension View {
  @MainActor
  public func inset(
    for key: WritableKeyPath<InsetableValues, CGSize>,
    alignment: SwiftUI.Alignment = .center,
    _ content: some View
  ) -> some View {
    overlay(alignment: alignment) {
      content
        .readSize { size in
          InsetableValues._current[keyPath: key] = size.size
        }
    }
  }

  @MainActor
  public func inset(
    for key: WritableKeyPath<InsetableValues, CGSize>,
    alignment: SwiftUI.Alignment = .center,
    @ViewBuilder _ content: @escaping () -> some View
  ) -> some View {
    inset(for: key, alignment: .bottom, content())
  }

  public func safeInset(
    from key: WritableKeyPath<InsetableValues, CGSize>,
    edge: SwiftUI.VerticalEdge = .bottom,
    alignment: SwiftUI.HorizontalAlignment = .center
  ) -> some View {
    @InsetValue(key) var value
    return safeAreaInset(edge: edge, alignment: alignment) {
      Spacer()
        .frame(width: value.width, height: value.height)
    }
  }
}
