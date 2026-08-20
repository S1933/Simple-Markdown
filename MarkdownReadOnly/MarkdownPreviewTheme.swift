import MarkdownUI
import SwiftUI

enum MarkdownPreviewTheme {
    static let simpleMarkdown = Theme()
        .text {
            FontSize(17)
            ForegroundColor(.primary)
        }
        .code {
            FontFamily(.custom("JetBrains Mono"))
            FontSize(.em(0.9))
            ForegroundColor(CodePalette.inline)
            BackgroundColor(CodePalette.inlineBackground)
        }
        .strong {
            FontWeight(.semibold)
        }
        .link {
            ForegroundColor(.accentColor)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(28)
                }
                .markdownMargin(top: 24, bottom: 8)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(22)
                }
                .markdownMargin(top: 20, bottom: 6)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(18)
                }
                .markdownMargin(top: 16, bottom: 4)
        }
        .heading4 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(16)
                }
                .markdownMargin(top: 12, bottom: 4)
        }
        .heading5 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(14)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .heading6 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(13)
                }
                .markdownMargin(top: 8, bottom: 4)
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 12)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(.secondary)
                    }
                    .padding(.leading, 12)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .codeBlock { configuration in
            configuration.label
                .markdownTextStyle {
                    FontFamily(.custom("JetBrains Mono"))
                    FontSize(.em(0.9))
                }
                .padding(12)
                .background(CodePalette.blockBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: 8, bottom: 12)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 4)
        }
        .thematicBreak {
            Divider()
                .overlay(Color.secondary.opacity(0.3))
                .markdownMargin(top: 16, bottom: 16)
        }
}
