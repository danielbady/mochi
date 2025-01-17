//
//  SearchFeature+Reducer.swift
//
//
//  Created MochiTeam on 4/18/23.
//  Copyright © 2023. All rights reserved.
//

import Architecture
import ComposableArchitecture
import LoggerClient
import ModuleLists
import OrderedCollections
import SharedModels

// MARK: - Cancellables

private enum Cancellables: Hashable {
  case fetchingItemsDebounce
  case fetchingSearchFilters
}

// MARK: - SearchFeature + Reducer

extension SearchFeature: Reducer {
  public var body: some ReducerOf<Self> {
    Scope(state: \.self, action: \.view) {
      BindingReducer()
    }

    Reduce { state, action in
      switch action {
      case .view(.didAppear):
        return state.fetchFilters()

      case let .view(.didShowNextPageIndicator(pagingId)):
        guard let value = state.searchResult.value, !value.pagingExists(pagingId) else {
          break
        }

        let selected = state.repoModuleId
        let searchQuery = state.query
        let searchFilters = state.selectedFilters

        state.searchResult.modify(\.loaded) { $0.update(pagingId, loadable: .loading) }

        return .run { send in
          await withTaskCancellation(id: Cancellables.fetchingItemsDebounce, cancelInFlight: true) {
            await send(
              .internal(
                .loadedPageResult(
                  pagingId,
                  .init {
                    try await moduleClient.withModule(id: selected) { module in
                      try await module.search(
                        .init(
                          query: searchQuery,
                          filters: searchFilters.map(\.searchQueryFilter),
                          page: pagingId
                        )
                      )
                    }
                  }
                )
              )
            )
          }
        } catch: { error, _ in
          logger.error("There was an error fetching page w/ id: \(pagingId.rawValue) - \(error.localizedDescription)")
        }

      case .view(.didTapClearQuery):
        return state.clearQuery()

      case .view(.didTapClearFilters):
        state.selectedFilters.removeAll()
        return state.fetchQuery()

      case .view(.didTapBackButton):
        return .run { await dismiss() }

      case let .view(.didTapFilter(filter, option)):
        if var storedFilter = state.selectedFilters[id: filter.id] {
          if storedFilter.options[id: option.id] == nil {
            storedFilter.options.append(option)
          } else {
            storedFilter.options.removeAll(where: \.id == option.id)
          }

          if storedFilter.options.isEmpty {
            state.selectedFilters[id: filter.id] = nil
          } else {
            state.selectedFilters[id: filter.id] = storedFilter
          }
        } else {
          state.selectedFilters.append(
            .init(
              id: filter.id,
              displayName: filter.displayName,
              multiselect: filter.multiselect,
              required: filter.required,
              options: [option]
            )
          )
        }

        return state.fetchQuery()

      case let .view(.didTapPlaylist(playlist)):
        return .send(.delegate(.playlistTapped(state.repoModuleId, playlist)))

      case .view(.binding(\.$query)):
        return state.fetchQuery()

      case .view(.binding):
        break

      case let .internal(.loadedSearchFilters(.success(filters))):
        state.allFilters = filters

      case .internal(.loadedSearchFilters(.failure)):
        state.allFilters = []

      case let .internal(.loadedItems(loadable)):
        state.searchResult = loadable.map { .init(initial: $0) }

      case let .internal(.loadedPageResult(pagingId, loadable)):
        state.searchResult.modify(\.loaded) { $0.update(pagingId, loadable: loadable) }

      case .delegate:
        break
      }
      return .none
    }
  }
}

extension SearchFeature.State {
  mutating func fetchFilters() -> Effect<SearchFeature.Action> {
    @Dependency(\.moduleClient) var moduleClient

    let selected = repoModuleId
    return .run { send in
      await withTaskCancellation(id: Cancellables.fetchingSearchFilters) {
        await send(
          .internal(
            .loadedSearchFilters(
              .init {
                try await moduleClient.withModule(id: selected) { instance in
                  try await instance.searchFilters()
                }
              }
            )
          )
        )
      }
    }
  }

  mutating func fetchQuery() -> Effect<SearchFeature.Action> {
    let selected = repoModuleId
    let searchQuery = query

    guard !searchQuery.isEmpty else {
      searchResult = .pending
      return .cancel(id: Cancellables.fetchingItemsDebounce)
    }

    @Dependency(\.moduleClient) var moduleClient

    searchResult = .loading

    let filters = selectedFilters

    return .run { send in
      try await withTaskCancellation(id: Cancellables.fetchingItemsDebounce, cancelInFlight: true) {
        try await Task.sleep(nanoseconds: 1_000_000 * 600)

        await send(
          .internal(
            .loadedItems(
              .init {
                try await moduleClient.withModule(id: selected) { module in
                  try await module.search(
                    .init(
                      query: searchQuery,
                      filters: filters.map(\.searchQueryFilter)
                    )
                  )
                }
              }
            )
          )
        )
      }
    } catch: { error, _ in
      logger.error("There was an error fetching page \(error.localizedDescription)")
    }
  }
}

extension SearchFeature.State {
  mutating func clearQuery() -> Effect<SearchFeature.Action> {
    query = ""
    searchResult = .pending
    return .cancel(id: Cancellables.fetchingItemsDebounce)
  }
}

extension SearchFilter {
  fileprivate var searchQueryFilter: SearchQuery.Filter {
    .init(id: id, optionId: options.map(\.id))
  }
}
