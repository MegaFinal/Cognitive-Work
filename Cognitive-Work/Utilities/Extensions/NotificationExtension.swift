//
//  NotificationExtension.swift
//  Cognitive-Work
//
//  Created by Jonas Fernando Nascimento Melo on 01/09/26.
//

import Foundation

extension Notification.Name {
    static let notAcceptShare = Notification.Name("notAcceptShare")
    static let didAcceptShare = Notification.Name("didAcceptShare")
    static let cloudKitDidChange = Notification.Name("cloudKitDidChange")
}
