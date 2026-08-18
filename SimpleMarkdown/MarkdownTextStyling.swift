import UIKit

enum MarkdownTextStyling {
    struct Palette {
        let text: UIColor
        let attenuated: UIColor
        let codeBackground: UIColor
        let accent: UIColor
    }

    static var defaultPalette: Palette {
        Palette(
            text: .label,
            attenuated: .secondaryLabel,
            codeBackground: .secondarySystemBackground,
            accent: UIColor.systemBlue
        )
    }

    static func baseFont(size: CGFloat = 16) -> UIFont {
        let raw = UIFont(name: "JetBrainsMono-Regular", size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: raw)
    }

    static func attributes(
        for style: MarkdownStyle,
        baseFont: UIFont,
        palette: Palette
    ) -> [NSAttributedString.Key: Any] {
        switch style {
        case .plain:
            return [.font: baseFont, .foregroundColor: palette.text]
        case .attenuated:
            return [.font: baseFont, .foregroundColor: palette.attenuated]
        case .bold:
            return [.font: scaled("JetBrainsMono-Bold", size: 16, fallback: .semibold), .foregroundColor: palette.text]
        case .italic:
            return [.font: scaled("JetBrainsMono-Italic", size: 16, fallback: .regular).italics(), .foregroundColor: palette.text]
        case .boldItalic:
            return [.font: scaled("JetBrainsMono-BoldItalic", size: 16, fallback: .semibold).italics(), .foregroundColor: palette.text]
        case .code:
            return [.font: scaled("JetBrainsMono-Regular", size: 15, fallback: .regular), .foregroundColor: palette.text, .backgroundColor: palette.codeBackground]
        case .link:
            return [.font: baseFont, .foregroundColor: palette.accent]
        case .heading(let level):
            return [.font: scaled("JetBrainsMono-Bold", size: headingSize(level), fallback: .bold), .foregroundColor: palette.text]
        case .blockquote:
            let font = scaled("JetBrainsMono-Italic", size: 16, fallback: .regular).italics()
            return [.font: font, .foregroundColor: palette.attenuated]
        case .codeFence:
            return [.font: baseFont, .foregroundColor: palette.attenuated]
        case .codeBlock:
            return [.font: scaled("JetBrainsMono-Regular", size: 15, fallback: .regular), .foregroundColor: palette.text, .backgroundColor: palette.codeBackground]
        case .hr:
            return [.font: baseFont, .foregroundColor: palette.attenuated]
        }
    }

    static func apply(
        to storage: NSTextStorage,
        text: String,
        range: NSRange,
        baseFont: UIFont,
        palette: Palette = defaultPalette
    ) {
        let nsText = text as NSString
        let clamped = NSRange(
            location: max(0, min(range.location, nsText.length)),
            length: max(0, min(range.length, nsText.length - range.location))
        )
        guard clamped.length > 0 else { return }

        let segments = MarkdownStyler.style(text, range: clamped)
        let base = attributes(for: .plain, baseFont: baseFont, palette: palette)

        storage.beginEditing()
        storage.setAttributes(base, range: clamped)
        for segment in segments {
            let segRange = NSRange(
                location: max(clamped.location, segment.range.location),
                length: min(NSMaxRange(segment.range), NSMaxRange(clamped)) - max(clamped.location, segment.range.location)
            )
            if segRange.length > 0 {
                storage.setAttributes(
                    attributes(for: segment.style, baseFont: baseFont, palette: palette),
                    range: segRange
                )
            }
        }
        storage.endEditing()
    }

    private static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 24
        case 3: return 21
        case 4: return 19
        case 5: return 17
        default: return 16
        }
    }

    private static func scaled(_ name: String, size: CGFloat, fallback weight: UIFont.Weight) -> UIFont {
        let raw = UIFont(name: name, size: size)
            ?? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: raw)
    }
}

private extension UIFont {
    func italics() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitItalic))
            ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
