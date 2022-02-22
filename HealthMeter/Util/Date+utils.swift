//
//  Date+utils.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 15.2.2022.
//

import Foundation

extension Date {
    /**
     - returns human readable String telling how long ago the date is compared to the current date. For example, "5 hours ago".
     */
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
