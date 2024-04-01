//
//  PlayerView.swift
//
//
//  Created by MochiTeam on 5/31/23.
//
//

import AVFoundation
import AVKit
import Combine
import Foundation
import SwiftUI
import ViewComponents

// MARK: - PiPStatus

public enum PiPStatus: Equatable, Sendable {
  case willStart
  case didStart
  case willStop
  case didStop
  case restoreUI
  case failed(Error)

  public var isInPiP: Bool {
    self == .willStart || self == .didStart
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.willStart, .willStart),
         (.didStart, .didStart),
         (.willStop, .willStop),
         (.didStop, .didStop),
         (.restoreUI, .restoreUI):
      true
    case let (.failed(lhsError), .failed(rhsError)):
      _isEqual(lhsError, rhsError)
    default:
      false
    }
  }
}

// MARK: - PlayerView

public struct PlayerView: PlatformAgnosticViewRepresentable {
  private let player: AVPlayer

  private let gravity: AVLayerVideoGravity
  private let enablePIP: Binding<Bool>

  private var pipIsSupportedCallback: ((Bool) -> Void)?
  private var pipIsActiveCallback: ((Bool) -> Void)?
  private var pipIsPossibleCallback: ((Bool) -> Void)?
  private var pipStatusCallback: ((PiPStatus) -> Void)?

  public init(
    player: AVPlayer,
    gravity: AVLayerVideoGravity = .resizeAspect,
    enablePIP: Binding<Bool>
  ) {
    self.player = player
    self.gravity = gravity
    self.enablePIP = enablePIP
  }

  public func makeCoordinator() -> Coordinator {
    .init(self)
  }

  public func makePlatformView(context: Context) -> AVPlayerView {
    let view = AVPlayerView(player: player)
    context.coordinator.initialize(view)
    return view
  }

  public func updatePlatformView(
    _ platformView: AVPlayerView,
    context: Context
  ) {
    if gravity != platformView.videoGravity {
      platformView.videoGravity = gravity
    }

    guard let pipController = context.coordinator.controller else {
      return
    }

    if enablePIP.wrappedValue {
      if !pipController.isPictureInPictureActive, pipController.isPictureInPicturePossible {
        pipController.startPictureInPicture()
      }
    } else {
      if pipController.isPictureInPictureActive {
        pipController.stopPictureInPicture()
      }
    }
  }
}

extension PlayerView {
  public func pictureInPictureIsActive(_ callback: @escaping (Bool) -> Void) -> Self {
    var view = self
    view.pipIsActiveCallback = callback
    return view
  }

  public func pictureInPictureIsPossible(_ callback: @escaping (Bool) -> Void) -> Self {
    var view = self
    view.pipIsPossibleCallback = callback
    return view
  }

  public func pictureInPictureIsSupported(_ callback: @escaping (Bool) -> Void) -> Self {
    var view = self
    view.pipIsSupportedCallback = callback
    return view
  }

  public func pictureInPictureStatus(_ callback: @escaping (PiPStatus) -> Void) -> Self {
    var view = self
    view.pipStatusCallback = callback
    return view
  }
}

// MARK: PlayerView.Coordinator

extension PlayerView {
  public final class Coordinator: NSObject {
    let videoPlayer: PlayerView
    var controller: AVPictureInPictureController?
    var cancellables = Set<AnyCancellable>()

    init(_ videoPlayer: PlayerView) {
      self.videoPlayer = videoPlayer
      super.init()
    }

    func initialize(_ view: AVPlayerView) {
      guard controller == nil, AVPictureInPictureController.isPictureInPictureSupported() else {
        return
      }

      let controller = AVPictureInPictureController(contentSource: .init(playerLayer: view.playerLayer))
      self.controller = controller

      controller.delegate = self
      #if os(iOS)
      controller.canStartPictureInPictureAutomaticallyFromInline = true
      #endif

      DispatchQueue.main.async { [weak self] in
        self?.videoPlayer.pipIsSupportedCallback?(true)
      }

      controller.publisher(for: \.isPictureInPictureActive)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isActive in
          self?.videoPlayer.pipIsActiveCallback?(isActive)
        }
        .store(in: &cancellables)

      controller.publisher(for: \.isPictureInPicturePossible)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isPossible in
          self?.videoPlayer.pipIsPossibleCallback?(isPossible)
        }
        .store(in: &cancellables)
    }
  }
}

// MARK: - PlayerView.Coordinator + AVPictureInPictureControllerDelegate

extension PlayerView.Coordinator: AVPictureInPictureControllerDelegate {
  public func pictureInPictureControllerWillStartPictureInPicture(_: AVPictureInPictureController) {
    DispatchQueue.main.async { [weak self] in
      self?.videoPlayer.pipStatusCallback?(.willStart)
    }
  }

  public func pictureInPictureControllerDidStartPictureInPicture(_: AVPictureInPictureController) {
    DispatchQueue.main.async { [weak self] in
      self?.videoPlayer.pipStatusCallback?(.didStart)
    }
  }

  public func pictureInPictureControllerWillStopPictureInPicture(_: AVPictureInPictureController) {
    DispatchQueue.main.async { [weak self] in
      self?.videoPlayer.pipStatusCallback?(.willStop)
    }
  }

  public func pictureInPictureControllerDidStopPictureInPicture(_: AVPictureInPictureController) {
    DispatchQueue.main.async { [weak self] in
      self?.videoPlayer.enablePIP.wrappedValue = false
      self?.videoPlayer.pipStatusCallback?(.didStop)
    }
  }

  public func pictureInPictureController(
    _: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.videoPlayer.enablePIP.wrappedValue = false
      self?.videoPlayer.pipStatusCallback?(.restoreUI)
    }
    completionHandler(true)
  }

  public func pictureInPictureController(
    _: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.videoPlayer.enablePIP.wrappedValue = false
      self?.videoPlayer.pipStatusCallback?(.failed(error))
    }
  }
}

// MARK: - AVPlayerView

public final class AVPlayerView: PlatformView {
  var playerLayer: AVPlayerLayer { (layer as? AVPlayerLayer).unsafelyUnwrapped }

  var player: AVPlayer? {
    get { playerLayer.player }
    set { playerLayer.player = newValue }
  }

  #if os(iOS)
  override public class var layerClass: AnyClass { AVPlayerLayer.self }
  #elseif os(macOS)
  override public func makeBackingLayer() -> CALayer { AVPlayerLayer() }
  #endif

  var videoGravity: AVLayerVideoGravity {
    get { playerLayer.videoGravity }
    set { playerLayer.videoGravity = newValue }
  }

  init(player: AVPlayer) {
    super.init(frame: .zero)
    #if os(macOS)
    wantsLayer = true
    #endif
    self.player = player
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
  (lhs as? any Equatable)?.isEqual(other: rhs) ?? false
}

extension Equatable {
  fileprivate func isEqual(other: Any) -> Bool {
    self == other as? Self
  }
}
