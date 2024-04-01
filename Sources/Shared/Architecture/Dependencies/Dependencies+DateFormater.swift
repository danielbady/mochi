//
//  Dependencies+DateFormater.swift
//
//
//  Created by MochiTeam on 5/2/23.
//
//

import ComposableArchitecture
import Foundation

// MARK: - SingleInstanceDateFormatter

@dynamicMemberLookup
public struct SingleInstanceDateFormatter {
  let dateFormatter: LockIsolated<DateFormatter>

  public subscript<Value>(dynamicMember dynamicMember: KeyPath<DateFormatter, Value>) -> Value {
    dateFormatter.value[keyPath: dynamicMember]
  }

  public func withFormatter<T>(_ work: (DateFormatter) -> T) -> T {
    dateFormatter.withValue { dateFormatter in
      work(dateFormatter)
    }
  }
}

// MARK: DependencyKey

extension SingleInstanceDateFormatter: DependencyKey {
  public static let liveValue: SingleInstanceDateFormatter = {
    let locked = LockIsolated(DateFormatter())
    return .init(dateFormatter: locked)
  }()
}

extension DependencyValues {
  public var dateFormatter: SingleInstanceDateFormatter {
    get { self[SingleInstanceDateFormatter.self] }
    set { self[SingleInstanceDateFormatter.self] = newValue }
  }
}

extension Date {
  public var timeAgo: String {
    let secondsAgo = Int(Date().timeIntervalSince(self))
    let minute = 60
    let hour = 60 * minute
    let day = 24 * hour
    let week = 7 * day
    let month = 4 * week

    let quotient: Int
    let unit: String
    if secondsAgo < minute {
      quotient = secondsAgo
      unit = "second"
    } else if secondsAgo < hour {
      quotient = secondsAgo / minute
      unit = "min"
    } else if secondsAgo < day {
      quotient = secondsAgo / hour
      unit = "hour"
    } else if secondsAgo < week {
      quotient = secondsAgo / day
      unit = "day"
    } else if secondsAgo < month {
      quotient = secondsAgo / week
      unit = "week"
    } else {
      quotient = secondsAgo / month
      unit = "month"
    }
    return "\(quotient) \(unit)\(quotient == 1 ? "" : "s") ago"
  }
}
