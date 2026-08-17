import SwiftUI

enum CodePalette {
    static let keyword = adaptive(
        light: UIColor(red: 0.55, green: 0.27, blue: 0.68, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.49, blue: 0.91, alpha: 1)
    )
    static let string = adaptive(
        light: UIColor(red: 0.78, green: 0.16, blue: 0.31, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.55, blue: 0.49, alpha: 1)
    )
    static let number = adaptive(
        light: UIColor(red: 0.10, green: 0.40, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.71, green: 0.86, blue: 0.65, alpha: 1)
    )
    static let comment = adaptive(
        light: UIColor(red: 0.40, green: 0.45, blue: 0.50, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1)
    )
    static let type = adaptive(
        light: UIColor(red: 0.20, green: 0.45, blue: 0.78, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.78, blue: 0.94, alpha: 1)
    )
    static let plain = adaptive(
        light: UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1),
        dark: UIColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1)
    )
    static let inline = adaptive(
        light: UIColor(red: 0.78, green: 0.16, blue: 0.31, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.78, blue: 0.58, alpha: 1)
    )
    static let inlineBackground = adaptive(
        light: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1)
    )
    static let blockBackground = adaptive(
        light: UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}
