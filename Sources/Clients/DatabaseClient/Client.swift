//
//  Client.swift
//
//
//  Created ErrorErrorError on 4/8/23.
//  Copyright © 2023. All rights reserved.
//

import Dependencies
import Foundation
import XCTestDynamicOverlay

// MARK: - DatabaseClient

public struct DatabaseClient: Sendable {
    public var initialize: @Sendable () async throws -> Void
    public var insert: @Sendable (any Entity) async throws -> any Entity
    public var update: @Sendable (any Entity) async throws -> any Entity
    public var delete: @Sendable (any Entity) async throws -> Void
    var fetch: @Sendable (any Entity.Type, any _Request) async throws -> [any Entity]
    var observe: @Sendable (any Entity.Type, any _Request) -> AsyncStream<[any Entity]>
}

public extension DatabaseClient {
    func fetch<T: Entity>(_ request: Request<T>) async throws -> [T] {
        try await (fetch(T.self, request) as? [T]) ?? []
    }

    func observe<T: Entity>(_ request: Request<T>) -> AsyncStream<[T]> {
         self.observe(T.self, request)
            .compactMap { ($0 as? [T]) ?? [] }
            .eraseToStream()
    }
}

// MARK: DatabaseClient.Error

public extension DatabaseClient {
    enum Error: Swift.Error {
        case managedContextNotAvailable
        case managedObjectIdIsTemporary
    }
}

// MARK: DependencyKey

extension DatabaseClient: DependencyKey {}

public extension DependencyValues {
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
