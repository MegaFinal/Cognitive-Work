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
    /// Posted as soon as the user opens an invite link, before the (slow) share acceptance.
    static let willAcceptShare = Notification.Name("willAcceptShare")
    /// Posted when accepting an invite fails, so screens can drop their loading state.
    static let shareAcceptFailed = Notification.Name("shareAcceptFailed")
    static let cloudKitDidChange = Notification.Name("cloudKitDidChange")
}
