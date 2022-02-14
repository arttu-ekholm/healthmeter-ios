//
//  NotificationService.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 1.2.2022.
//

import Foundation
import UIKit

class NotificationService {
    enum NotificationServiceError: Error {
        case appIsActive
    }

    let application: UIApplication
    let notificationCenter: UNUserNotificationCenter

    init(application: UIApplication = UIApplication.shared,
         notificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()) {
        self.application = application
        self.notificationCenter = notificationCenter
    }

    func postNotification(title: String, body: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        DispatchQueue.main.async {
            print("posting notification with title: \(title), message: \(body)")
            if self.application.applicationState != .active {
                self.application.applicationIconBadgeNumber = 1
                completion?(.failure(NotificationServiceError.appIsActive))
            } else {
                self.application.applicationIconBadgeNumber = 0
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default

            // choose a random identifier
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

            // add our notification request
            self.notificationCenter.add(request) { error in
               if let error = error {
                   print("posting the notification failed with error: \(error)")
                   completion?(.failure(error))
                   UIApplication.shared.applicationIconBadgeNumber = 9
               } else {
                   print("notification posted successfully")
                   completion?(.success(()))
               }
           }
        }
    }
}
