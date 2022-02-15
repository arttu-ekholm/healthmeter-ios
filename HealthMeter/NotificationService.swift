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

    private let applicationProxy: ApplicationProxy
    private let notificationCenterProxy: NotificationCenterProxy

    init(applicationProxy: ApplicationProxy = ApplicationProxy(),
         notificationCenterProxy: NotificationCenterProxy = NotificationCenterProxy()) {
        self.applicationProxy = applicationProxy
        self.notificationCenterProxy = notificationCenterProxy
    }

    func postNotification(title: String, body: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        DispatchQueue.main.async {
            print("posting notification with title: \(title), message: \(body)")
            guard self.applicationProxy.applicationState != .active else {
                completion?(.failure(NotificationServiceError.appIsActive))
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            self.notificationCenterProxy.add(request) { error in
               if let error = error {
                   print("posting the notification failed with error: \(error)")
                   completion?(.failure(error))
               } else {
                   print("notification posted successfully")
                   completion?(.success(()))
               }
           }
        }
    }
}

class ApplicationProxy {
    var applicationState: UIApplication.State {
        return UIApplication.shared.applicationState
    }

    var applicationIconBadgeNumber: Int {
        get {
            return UIApplication.shared.applicationIconBadgeNumber
        } set {
            UIApplication.shared.applicationIconBadgeNumber = newValue
        }
    }
}

class NotificationCenterProxy {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        UNUserNotificationCenter.current().add(request, withCompletionHandler: completionHandler)
    }
}
