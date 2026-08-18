import SwiftUI

struct EditorTheme {
    let body = Font.system(size: 17)
    let mono = Font.custom("JetBrainsMono-Regular", size: 16, relativeTo: .body)
    let horizontalPadding: CGFloat = 24
    let verticalPadding: CGFloat = 20
    let maxLineWidth: CGFloat = 680

    static let `default` = EditorTheme()
}
