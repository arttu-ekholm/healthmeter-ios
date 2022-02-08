//
//  Config.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 7.2.2022.
//

import Foundation

class Config {
    static let shared: Config = Config()

    var displayDebugView = false
    var postDebugNotifications = false
}
