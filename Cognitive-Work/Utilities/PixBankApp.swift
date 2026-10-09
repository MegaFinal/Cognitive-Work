//
//  PixBankApp.swift
//  Cognitive-Work
//

import SwiftUI
import UIKit

/// A banking app the Pix payment sheet can open.
///
/// iOS doesn't let an app list what else is installed, and there is no public way to open a bank
/// straight on its "Pix copia e cola" screen. So the sheet copies the code and opens the bank by
/// trying the URL schemes (and, last, the universal link) it is believed to answer to; most banks
/// then offer to paste the code.
///
/// > Important: The schemes are best guesses, not documented by the banks. A bank is shown as
/// > "yours" when `canOpenURL` finds it (needs the scheme under `LSApplicationQueriesSchemes` in
/// > Info.plist, max 50) or once it has opened successfully on this device (see ``remember()``).
/// > Brand colors are approximations.
struct PixBankApp: Identifiable, Hashable {
    let name: String
    let schemes: [String]
    /// Opened with `.universalLinksOnly`, so it never falls back to Safari.
    var universalLink: URL? = nil
    let colorHex: String
    var textHex: String = "FFFFFF"

    var id: String { name }

    var color: Color { Color(hex: colorHex) ?? .blue }
    var textColor: Color { Color(hex: textHex) ?? .white }

    static let all: [PixBankApp] = [
        .init(name: "Nubank", schemes: ["nubank", "nuapp", "nubankapp"],
              universalLink: URL(string: "https://nubank.com.br/"), colorHex: "820AD1"),
        .init(name: "Inter", schemes: ["bancointer", "interapp"],
              universalLink: URL(string: "https://inter.co/"), colorHex: "FF7A00"),
        .init(name: "Itaú", schemes: ["itauvarejo", "itau", "itaupersonnalite"], colorHex: "EC7000"),
        .init(name: "Bradesco", schemes: ["bradesco", "bradescoapp"], colorHex: "CC092F"),
        .init(name: "Banco do Brasil", schemes: ["bbapp", "bancodobrasil"], colorHex: "FCFC30", textHex: "465EFF"),
        .init(name: "Santander", schemes: ["santander", "santanderbr"], colorHex: "EC0000"),
        .init(name: "Caixa", schemes: ["caixatem", "caixaapp"], colorHex: "005CA9"),
        .init(name: "C6 Bank", schemes: ["c6bank"], colorHex: "242424"),
        .init(name: "PicPay", schemes: ["picpay"],
              universalLink: URL(string: "https://picpay.me/"), colorHex: "21C25E"),
        .init(name: "Mercado Pago", schemes: ["mercadopago"],
              universalLink: URL(string: "https://www.mercadopago.com.br/"), colorHex: "00B1EA"),
        .init(name: "PagBank", schemes: ["pagbank", "pagseguro"], colorHex: "1BB99A"),
        .init(name: "Neon", schemes: ["neon", "neonapp"], colorHex: "0090FF"),
        .init(name: "BTG Pactual", schemes: ["btgpactual", "btgbanking"], colorHex: "001E62"),
        .init(name: "Next", schemes: ["banconext", "nextapp"], colorHex: "00E35B", textHex: "111111"),
        .init(name: "Sicoob", schemes: ["sicoob", "sicoobapp"], colorHex: "003641"),
        .init(name: "Sicredi", schemes: ["sicredi", "sicrediapp"], colorHex: "3FA110"),
        .init(name: "Banrisul", schemes: ["banrisul"], colorHex: "0058A6"),
        .init(name: "Will Bank", schemes: ["willbank"], colorHex: "FFE000", textHex: "1A1A1A"),
        .init(name: "Banco Pan", schemes: ["bancopan"], colorHex: "00AEEF"),
        .init(name: "Banco Original", schemes: ["bancooriginal"], colorHex: "00A859"),
        .init(name: "XP", schemes: ["xpinvestimentos"], colorHex: "000000")
    ]

    /// Every scheme of every bank, for Info.plist.
    static var allSchemes: [String] { all.flatMap(\.schemes) }

    // MARK: - Finding

    /// Found by `canOpenURL` (only works for schemes listed in Info.plist).
    @MainActor
    var isDetected: Bool {
        schemes
            .compactMap { URL(string: "\($0)://") }
            .contains { UIApplication.shared.canOpenURL($0) }
    }

    private static let openedKey = "pixBanksOpened"

    /// Names of the banks that already opened on this device, last used first.
    private static var openedNames: [String] {
        UserDefaults.standard.stringArray(forKey: openedKey) ?? []
    }

    /// Marks this bank as installed and puts it first next time.
    func remember() {
        var names = Self.openedNames.filter { $0 != name }
        names.insert(name, at: 0)
        UserDefaults.standard.set(names, forKey: Self.openedKey)
    }

    /// The banks on this device (last used first) and every other one.
    @MainActor
    static func split() -> (yours: [PixBankApp], others: [PixBankApp]) {
        let opened = openedNames
        let yours = all
            .filter { opened.contains($0.name) || $0.isDetected }
            .sorted { (opened.firstIndex(of: $0.name) ?? .max) < (opened.firstIndex(of: $1.name) ?? .max) }
        let yourNames = Set(yours.map(\.name))
        return (yours, all.filter { !yourNames.contains($0.name) })
    }

    // MARK: - Opening

    /// Tries every scheme, then the universal link. `open` needs no Info.plist entry, so this also
    /// reaches banks `canOpenURL` can't see.
    ///
    /// - Returns: `true` when some app opened.
    @MainActor
    func open() async -> Bool {
        for scheme in schemes {
            guard let url = URL(string: "\(scheme)://") else { continue }
            if await UIApplication.shared.open(url) {
                remember()
                return true
            }
        }
        if let universalLink, await UIApplication.shared.open(universalLink, options: [.universalLinksOnly: true]) {
            remember()
            return true
        }
        return false
    }
}
