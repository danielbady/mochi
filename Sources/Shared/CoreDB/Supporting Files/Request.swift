//  Request.swift
//  mochi
//
//  Created by MochiTeam on 11/16/22.
//
//  Modified version of https://github.com/prisma-ai/Sworm

import CoreData
import Foundation

// MARK: - _Request

public protocol _Request {
  associatedtype SomeEntity: Entity
  var fetchLimit: Int? { get set }
  var predicate: NSPredicate? { get set }
  var sortDescriptors: [SortDescriptor] { get set }
}

// MARK: - Request

public struct Request<SomeEntity: Entity>: _Request {
  public var fetchLimit: Int?
  public var predicate: NSPredicate?
  public var sortDescriptors: [SortDescriptor] = []

  fileprivate init() {}
}

extension Request {
  public func `where`(
    _ predicate: some PredicateProtocol<SomeEntity>
  ) -> Self {
    var obj = self
    obj.predicate = predicate
    return obj
  }

  public func sort(
    _ keyPath: KeyPath<SomeEntity, some Comparable>,
    ascending: Bool = true
  ) -> Self {
    var obj = self
    obj.sortDescriptors.append(
      .init(
        keyPath: keyPath,
        ascending: ascending
      )
    )
    return obj
  }

  public func limit(_ count: Int) -> Self {
    var obj = self
    obj.fetchLimit = max(0, count)
    return obj
  }

  public static var all: Self {
    .init()
  }
}

extension Request {
  func makeFetchRequest<ResultType: NSFetchRequestResult>(ofType resultType: NSFetchRequestResultType = .managedObjectResultType) -> NSFetchRequest<ResultType> {
    let properties = SomeEntity._$properties.filter { !$0.isRelation }.map(\.propertyName)
    let fetchRequest = NSFetchRequest<ResultType>(entityName: SomeEntity.entityName)
    fetchRequest.resultType = resultType
    fetchRequest.propertiesToFetch = properties
    fetchRequest.includesPropertyValues = !properties.isEmpty

    fetchLimit.flatMap { fetchRequest.fetchLimit = $0 }
    predicate.flatMap { fetchRequest.predicate = $0 }

    if !sortDescriptors.isEmpty {
      fetchRequest.sortDescriptors = sortDescriptors.map(\.object)
    }

    return fetchRequest
  }
}

// MARK: - SortDescriptor

public struct SortDescriptor: Equatable {
  let keyPathString: String
  var ascending = true
}

extension SortDescriptor {
  var object: NSSortDescriptor {
    .init(
      key: keyPathString,
      ascending: ascending
    )
  }
}

extension SortDescriptor {
  init(
    keyPath: KeyPath<some Any, some Any>,
    ascending: Bool
  ) {
    self.keyPathString = NSExpression(forKeyPath: keyPath).keyPath
    self.ascending = ascending
  }
}

// MARK: - PredicateProtocol

public protocol PredicateProtocol<Root>: NSPredicate {
  associatedtype Root: Entity
}

// MARK: - CompoundPredicate

public final class CompoundPredicate<Root: Entity>: NSCompoundPredicate, PredicateProtocol {}

// MARK: - ComparisonPredicate

public final class ComparisonPredicate<Root: Entity>: NSComparisonPredicate, PredicateProtocol {}

// MARK: compound operators

extension PredicateProtocol {
  public static func && (
    lhs: Self,
    rhs: Self
  ) -> CompoundPredicate<Root> {
    CompoundPredicate(type: .and, subpredicates: [lhs, rhs])
  }

  public static func || (
    lhs: Self,
    rhs: Self
  ) -> CompoundPredicate<Root> {
    CompoundPredicate(type: .or, subpredicates: [lhs, rhs])
  }

  public static prefix func ! (not: Self) -> CompoundPredicate<Root> {
    CompoundPredicate(type: .not, subpredicates: [not])
  }
}

// MARK: - comparison operators

extension PrimitiveValue where Self: Equatable {
  public static func == <R>(
    kp: KeyPath<R, Self>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .equalTo, value)
  }

  public static func != <R>(
    kp: KeyPath<R, Self>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .notEqualTo, value)
  }
}

extension Optional where Wrapped: PrimitiveValue {
  public static func == <R>(
    kp: KeyPath<R, Wrapped>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .equalTo, value)
  }

  public static func != <R>(
    kp: KeyPath<R, Wrapped>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .notEqualTo, value)
  }
}

extension PrimitiveValue where Self: Comparable {
  public static func > <R>(
    kp: KeyPath<R, Self>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .greaterThan, value)
  }

  public static func < <R>(
    kp: KeyPath<R, Self>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .lessThan, value)
  }

  public static func <= <R>(
    kp: KeyPath<R, Self>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .lessThanOrEqualTo, value)
  }

  public static func >= <R>(
    kp: KeyPath<R, Self>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .greaterThanOrEqualTo, value)
  }
}

extension Optional where Wrapped: PrimitiveValue & Comparable {
  public static func > <R>(
    kp: KeyPath<R, Wrapped>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .greaterThan, value)
  }

  public static func < <R>(
    kp: KeyPath<R, Wrapped>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .lessThan, value)
  }

  public static func <= <R>(
    kp: KeyPath<R, Wrapped>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .lessThanOrEqualTo, value)
  }

  public static func >= <R>(
    kp: KeyPath<R, Wrapped>,
    value: Self
  ) -> ComparisonPredicate<R> {
    ComparisonPredicate(kp, .greaterThanOrEqualTo, value)
  }
}

// MARK: - internal

extension ComparisonPredicate {
  convenience init<Value: PrimitiveValue>(
    _ keyPath: KeyPath<Root, Value>,
    _ op: NSComparisonPredicate.Operator,
    _ value: Value?
  ) {
    let keyPathName = Root._$properties.first { $0.property.keyPath == keyPath }.unsafelyUnwrapped.name
    let ex1 = NSExpression(forKeyPath: keyPathName)
    let ex2 = NSExpression(forConstantValue: value)
    self.init(leftExpression: ex1, rightExpression: ex2, modifier: .direct, type: op)
  }
}
