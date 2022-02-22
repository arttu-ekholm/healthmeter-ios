//
//  Haptics.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 22.2.2022.
//

import UIKit

class Haptics {
    func playHapticFeedbackEvent() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func playSuccessHapticFeedbackEvent() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}



