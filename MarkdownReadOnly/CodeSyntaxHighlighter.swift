import MarkdownUI
import SwiftUI

struct AppCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(Self.highlightedCode(code, language: language))
    }

    static func highlightedCode(_ code: String, language: String?) -> AttributedString {
        let rules: [CodeRule]
        switch language?.lowercased() {
        case "swift": rules = swiftRules
        case "javascript", "js", "typescript", "ts": rules = jsRules
        case "json": rules = jsonRules
        case "bash", "sh", "shell", "zsh": rules = shellRules
        case "python", "py": rules = pythonRules
        case "html", "xml": rules = markupRules
        default: rules = []
        }
        return applyHighlighting(code, rules: rules)
    }
}

private enum CodeToken {
    case plain
    case keyword
    case string
    case number
    case comment
    case type
}

private struct CodeRule {
    let regex: NSRegularExpression
    let token: CodeToken
    let priority: Int

    init(pattern: String, token: CodeToken, priority: Int? = nil) {
        regex = try! NSRegularExpression(pattern: pattern)
        self.token = token
        self.priority = priority ?? token.defaultPriority
    }
}

private extension CodeToken {
    var defaultPriority: Int {
        switch self {
        case .comment: return 0
        case .string: return 1
        case .keyword: return 2
        case .type: return 3
        case .number: return 4
        case .plain: return 5
        }
    }
}

private func applyHighlighting(_ code: String, rules: [CodeRule]) -> AttributedString {
    guard code.count <= 20_000 else { return styled(code, color: CodePalette.plain) }
    let nsCode = code as NSString
    let fullRange = NSRange(location: 0, length: nsCode.length)
    var matches: [(range: NSRange, token: CodeToken, priority: Int)] = []
    for rule in rules {
        rule.regex.enumerateMatches(in: code, range: fullRange) { result, _, _ in
            if let range = result?.range, range.length > 0 {
                matches.append((range, rule.token, rule.priority))
            }
        }
    }
    matches.sort {
        if $0.range.location != $1.range.location {
            return $0.range.location < $1.range.location
        }
        if $0.range.length != $1.range.length {
            return $0.range.length > $1.range.length
        }
        return $0.priority < $1.priority
    }
    var deduped: [(NSRange, CodeToken)] = []
    var lastEnd = 0
    for (range, token, _) in matches {
        if range.location >= lastEnd {
            deduped.append((range, token))
            lastEnd = range.location + range.length
        }
    }

    var result = AttributedString()
    var cursor = 0
    for (range, token) in deduped {
        if range.location > cursor {
            let plainRange = NSRange(location: cursor, length: range.location - cursor)
            let chunk = nsCode.substring(with: plainRange)
            result.append(styled(chunk, color: CodePalette.plain))
        }
        let chunk = nsCode.substring(with: range)
        result.append(styled(chunk, color: color(for: token)))
        cursor = range.location + range.length
    }
    if cursor < nsCode.length {
        let tail = nsCode.substring(from: cursor)
        result.append(styled(tail, color: CodePalette.plain))
    }
    return result
}

private func styled(_ text: String, color: Color) -> AttributedString {
    var result = AttributedString(text)
    result.font = .custom("JetBrainsMono-Regular", size: 14, relativeTo: .body)
    result.foregroundColor = color
    return result
}

private func color(for token: CodeToken) -> Color {
    switch token {
    case .plain: return CodePalette.plain
    case .keyword: return CodePalette.keyword
    case .string: return CodePalette.string
    case .number: return CodePalette.number
    case .comment: return CodePalette.comment
    case .type: return CodePalette.type
    }
}

private let swiftRules: [CodeRule] = [
    CodeRule(pattern: "//[^\n]*", token: .comment),
    CodeRule(pattern: "/\\*[\\s\\S]*?\\*/", token: .comment),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "\\b(?:let|var|func|class|struct|enum|protocol|extension|import|return|if|else|guard|while|for|in|do|try|catch|throw|throws|init|deinit|self|Self|super|nil|true|false|public|private|internal|fileprivate|open|static|final|lazy|weak|unowned|async|await|some|any|where|as|is|switch|case|default|break|continue)\\b", token: .keyword),
    CodeRule(pattern: "\\b(?:Int|String|Double|Float|Bool|Array|Dictionary|Set|Optional|Any|AnyObject|Void|UInt|Int8|Int16|Int32|Int64|Character|Data|Date|URL|UUID|Error|Result|Sequence|Collection|Iterator)\\b", token: .type),
    CodeRule(pattern: "\\b\\d+(?:\\.\\d+)?\\b", token: .number),
]

private let jsRules: [CodeRule] = [
    CodeRule(pattern: "//[^\n]*", token: .comment),
    CodeRule(pattern: "/\\*[\\s\\S]*?\\*/", token: .comment),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "'(?:[^'\\\\\n]|\\\\.)*'", token: .string),
    CodeRule(pattern: "`(?:[^`\\\\\n]|\\\\.)*`", token: .string),
    CodeRule(pattern: "\\b(?:const|let|var|function|return|if|else|while|for|do|class|extends|import|export|from|new|this|super|null|undefined|true|false|async|await|try|catch|throw|of|in|typeof|instanceof|switch|case|default|break|continue|yield)\\b", token: .keyword),
    CodeRule(pattern: "\\b(?:string|number|boolean|object|Array|Promise|Map|Set|Symbol|BigInt|Function|Error)\\b", token: .type),
    CodeRule(pattern: "\\b\\d+(?:\\.\\d+)?\\b", token: .number),
]

private let jsonRules: [CodeRule] = [
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"\\s*:", token: .keyword),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "\\b(?:true|false|null)\\b", token: .keyword),
    CodeRule(pattern: "\\b-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", token: .number),
]

private let shellRules: [CodeRule] = [
    CodeRule(pattern: "#[^\n]*", token: .comment),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "'[^'\n]*'", token: .string),
    CodeRule(pattern: "\\$\\w+", token: .type),
    CodeRule(pattern: "\\$\\{[^}]+\\}", token: .type),
    CodeRule(pattern: "\\b(?:if|then|else|elif|fi|for|in|do|done|while|case|esac|function|return|exit|export|local|alias)\\b", token: .keyword),
]

private let pythonRules: [CodeRule] = [
    CodeRule(pattern: "#[^\n]*", token: .comment),
    CodeRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", token: .string),
    CodeRule(pattern: "'''[\\s\\S]*?'''", token: .string),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "'(?:[^'\\\\\n]|\\\\.)*'", token: .string),
    CodeRule(pattern: "\\b(?:def|class|return|if|elif|else|while|for|in|not|and|or|is|None|True|False|import|from|as|try|except|finally|raise|with|yield|lambda|pass|break|continue|global|nonlocal)\\b", token: .keyword),
    CodeRule(pattern: "\\b(?:int|str|float|bool|list|dict|tuple|set|bytes|object|Optional|Any|Union)\\b", token: .type),
    CodeRule(pattern: "\\b\\d+(?:\\.\\d+)?\\b", token: .number),
]

private let markupRules: [CodeRule] = [
    CodeRule(pattern: "<!--[\\s\\S]*?-->", token: .comment),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "'(?:[^'\\\\\n]|\\\\.)*'", token: .string),
    CodeRule(pattern: "</?[a-zA-Z][a-zA-Z0-9-]*", token: .keyword),
    CodeRule(pattern: "/?>", token: .keyword),
    CodeRule(pattern: "\\b(?:DOCTYPE|html|head|body|div|span|p|a|img|script|style|link|meta|title)\\b", token: .type),
]
