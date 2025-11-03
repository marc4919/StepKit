//
//  Helpers.swift
//  StepKit Playground
//
//  Created by Marc Garcia Teodoro on 24/10/25.
//

import Foundation

/// Returns today's date in ISO 8601 format (YYYY-MM-DD) for the specified timezone
func todayISO(in timeZoneID: String = "Europe/Madrid") -> String {
    let tz = TimeZone(identifier: timeZoneID) ?? .current
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = tz
    let now = Date()
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    let date = cal.date(from: comps) ?? now
    let fmt = DateFormatter()
    fmt.calendar = cal
    fmt.timeZone = tz
    fmt.dateFormat = "yyyy-MM-dd"
    return fmt.string(from: date)
}
