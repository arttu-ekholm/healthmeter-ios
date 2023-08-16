//
//  NotificationService.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 1.2.2022.
//

import Foundation
import UIKit

/**
 Posts push notifications
 */
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
    private let application = UIApplication.shared
    var applicationState: UIApplication.State {
        return application.applicationState
    }

    var applicationIconBadgeNumber: Int {
        get {
            return application.applicationIconBadgeNumber
        } set {
            application.applicationIconBadgeNumber = newValue
        }
    }
}

class NotificationCenterProxy: NSObject {
    private let notificationCenter = UNUserNotificationCenter.current()

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        notificationCenter.add(request, withCompletionHandler: completionHandler)
    }

    override init() {
        super.init()

        notificationCenter.delegate = self
    }
}

extension NotificationCenterProxy: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Allow the app to show the notifications when it is active
        completionHandler([.badge, .banner, .list, .sound])
    }
}
