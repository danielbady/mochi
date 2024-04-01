//
//  RepoPackagesFeature+Reducer.swift
//
//
//  Created by MochiTeam on 8/16/23.
//
//

import Architecture
import ComposableArchitecture
import Foundation
import RepoClient

extension RepoPackagesFeature {
  private enum Cancellable: Hashable {
    case fetchingModules
  }

  @ReducerBuilder<State, Action> public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onTask):
        let repoId = state.repo.id
        return .merge(
          state.fetchRemoteModules(),
          .run { send in
            let stream = repoClient.downloads()
            for await value in stream {
              let filteredRepo = value.filter(\.key.repoId == repoId)
              let mapped = Dictionary(uniqueKeysWithValues: filteredRepo.map { ($0.moduleId, $1) })
              await send(.internal(.downloadStates(mapped)))
            }
          },
          .run { send in
            for await repos in repoClient.repos(.all) {
              await send(.internal(.updateRepo(repos[id: repoId])))
            }
          }
        )

      case .view(.didTapToRefreshRepo):
        state.repo._$id = .init()
        return state.fetchRemoteModules(forced: true)

      case let .view(.didTapAddModule(moduleId)):
        guard let manifest = state.packages.value?.map(\.latestModule).first(where: \.id == moduleId) else {
          break
        }

        let repoId = state.repo.id
        repoClient.installModule(repoId, manifest)
        return .run { try await moduleClient.removeCachedModule(manifest.id(repoID: repoId)) }

      case let .view(.didTapRemoveModule(moduleId)):
        return .run { send in
          try await Task.sleep(nanoseconds: 1_000_000_000)
          await send(.internal(.delayDeletingModule(id: moduleId)))
        }

      case .view(.didTapClose):
        return .run { _ in await dismiss() }

      case let .internal(.updateRepo(repo)):
        state.repo = repo ?? state.repo

      case let .internal(.repoModules(modules)):
        state.packages = modules.map { manifests in
          Dictionary(grouping: manifests, by: \.id)
            .map(\.value)
            .filter { !$0.isEmpty }
            .sorted { $0.latestModule.name < $1.latestModule.name }
        }

      case let .internal(.downloadStates(modules)):
        state.downloadStates = modules

      case let .internal(.delayDeletingModule(moduleID)):
        guard let module = state.repo.modules[id: moduleID] else {
          break
        }

        state.repo.modules.remove(module)

        let repoId = state.repo.id
        return .merge(
          .run { try await repoClient.removeModule(module.id(repoID: repoId)) },
          .run { try await moduleClient.removeCachedModule(module.id(repoID: repoId)) }
        )

      case .delegate:
        break
      }
      return .none
    }
  }
}

extension RepoPackagesFeature.State {
  mutating func fetchRemoteModules(forced: Bool = false) -> Effect<RepoPackagesFeature.Action> {
    @Dependency(\.repoClient) var repoClient

    // TODO: Cache request

    guard !packages.hasInitialized || forced else {
      return .none
    }

    packages = .pending

    let id = repo.id
    return .run { send in
      try await withTaskCancellation(id: RepoPackagesFeature.Cancellable.fetchingModules, cancelInFlight: true) {
        await send(.internal(.repoModules(.loading)))
        let modules = try await repoClient.fetchModulesMetadata(id)
        await send(.internal(.repoModules(.loaded(modules))))
      }
    } catch: { error, send in
      await send(.internal(.repoModules(.failed(error))))
    }
  }
}
