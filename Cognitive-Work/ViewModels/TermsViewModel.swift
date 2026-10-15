//
//  TermsViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 09/10/26.
//

import Foundation

/// Whether the user accepted the current Terms of Use, and what the terms screens show.
@MainActor
@Observable
final class TermsViewModel {

    enum Decision: Equatable {
        case pending
        case accepted
        case declined
    }

    let terms: TermsOfUse

    private(set) var decision: Decision

    var isConfirmingAcceptance = false

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let acceptedVersion = "termsAcceptedVersion"
        static let declined = "termsDeclined"
    }

    init(terms: TermsOfUse = .current, defaults: UserDefaults = .standard) {
        self.terms = terms
        self.defaults = defaults

        if defaults.string(forKey: Keys.acceptedVersion) == terms.version {
            decision = .accepted
        } else if defaults.bool(forKey: Keys.declined) {
            decision = .declined
        } else {
            decision = .pending
        }
    }

    var isShowingTerms: Bool { decision == .pending }

    // MARK: - Texts

    var title: String { L10n.tr("Termos de Uso") }

    var subtitle: String {
        L10n.tr("Versão %@ · Última atualização: %@", terms.version, terms.lastUpdated)
    }

    var confirmationTitle: String { L10n.tr("Termos de Uso") }

    var confirmationMessage: String {
        L10n.tr("Ao tocar em Concordar, você aceita os Termos de Uso do %@.", terms.appName)
    }

    var farewellTitle: String { L10n.tr("Tudo bem, até logo!") }

    var farewellMessage: String {
        L10n.tr("Para usar o %@ é preciso aceitar os Termos de Uso. Se mudar de ideia, é só rever os termos: a casa vai estar te esperando.", terms.appName)
    }

    // MARK: - Actions

    func requestAcceptance() {
        isConfirmingAcceptance = true
    }

    func accept() {
        defaults.set(terms.version, forKey: Keys.acceptedVersion)
        defaults.set(false, forKey: Keys.declined)
        decision = .accepted
    }

    func decline() {
        defaults.removeObject(forKey: Keys.acceptedVersion)
        defaults.set(true, forKey: Keys.declined)
        decision = .declined
    }

    /// From the farewell screen: shows the terms again.
    func reviewTerms() {
        decision = .pending
    }
}
