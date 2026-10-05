//
//  FontExtension.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 05/10/26.
//

import SwiftUI
import UIKit
import CoreText

/// The app's title typeface: **Alan Sans**, a variable font (`wght` 300–900) registered in
/// `Info.plist` under `UIAppFonts`.
///
/// The file has a single named face (`AlanSans-Light`), so `Font.custom` plus `.bold()` /
/// `.fontWeight(_:)` can't be trusted to pick the weight — SwiftUI may just synthesise it.
/// The weight is set straight on the `wght` axis instead.
///
/// > Note: The app pins `.dynamicTypeSize(.large)` (`Cognitive_WorkApp`), so sizes are fixed,
/// > like the `.system(size:)` fonts they replace.
enum AppFont {
    /// PostScript name of the default instance of the variable font.
    static let postScriptName = "AlanSans-Light"
    
    /// `'wght'` as the four-char code Core Text uses to key variation axes.
    private static let weightAxis = 0x7767_6874
    
    /// The axis range the font file supports.
    private static let weightRange: ClosedRange<CGFloat> = 300...900
    
    /// Alan Sans at `size` and `weight`, or the system font if the file isn't registered
    /// (e.g. missing from the target), so a title never disappears.
    static func uiFont(size: CGFloat, weight: Font.Weight) -> UIFont {
        guard UIFont(name: postScriptName, size: size) != nil else {
            return .systemFont(ofSize: size, weight: uiWeight(for: weight))
        }
        
        let axisValue = min(max(axisValue(for: weight), weightRange.lowerBound), weightRange.upperBound)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: postScriptName,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: axisValue]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
    
    /// Default point size of each text style at the `.large` content size the app is pinned to.
    static func pointSize(for style: Font.TextStyle) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        return UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: uiTextStyle(for: style), compatibleWith: traits)
            .pointSize
    }
    
    /// Applies Alan Sans to navigation bar titles (`.navigationTitle`), inline and large.
    ///
    /// Only the title attributes are touched, so each screen keeps its bar background.
    /// Call once at launch.
    static func applyToNavigationBars() {
        let bar = UINavigationBar.appearance()
        bar.titleTextAttributes = [.font: uiFont(size: pointSize(for: .headline), weight: .bold)]
        bar.largeTitleTextAttributes = [.font: uiFont(size: pointSize(for: .largeTitle), weight: .bold)]
    }
    
    // MARK: - Mapping
    
    private static func axisValue(for weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight, .thin, .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }
    
    private static func uiWeight(for weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
    
    private static func uiTextStyle(for style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

extension Font {
    /// Title font (Alan Sans) at a fixed size. Use for every screen, section and card title.
    ///
    /// Pass the weight here rather than chaining `.bold()` / `.fontWeight(_:)`: see ``AppFont``.
    static func appTitle(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font(AppFont.uiFont(size: size, weight: weight))
    }
    
    /// Title font (Alan Sans) at the size of a system text style, e.g. `.appTitle(.largeTitle)`.
    static func appTitle(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        appTitle(size: AppFont.pointSize(for: style), weight: weight)
    }
}
