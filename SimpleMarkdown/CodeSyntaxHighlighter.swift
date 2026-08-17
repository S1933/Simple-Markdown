import MarkdownUI
import SwiftUI

struct AppCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        guard let language = language?.lowercased() else {
            return plain(code)
        }
        switch language {
        case "swift":
            return SwiftHighlighter.highlight(code)
        case "javascript", "js", "typescript", "ts":
            return JavaScriptHighlighter.highlight(code)
        case "json":
            return JSONHighlighter.highlight(code)
        case "bash", "sh", "shell", "zsh":
            return ShellHighlighter.highlight(code)
        case "python", "py":
            return PythonHighlighter.highlight(code)
        case "html", "xml":
            return MarkupHighlighter.highlight(code)
        default:
            return plain(code)
        }
    }

    private func plain(_ code: String) -> Text {
        Text(code)
            .font(.custom("JetBrains Mono", size: 14))
            .foregroundColor(CodePalette.plain)
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
    let pattern: String
    let token: CodeToken
}

private func applyHighlighting(_ code: String, rules: [CodeRule]) -> Text {
    let nsCode = code as NSString
    let fullRange = NSRange(location: 0, length: nsCode.length)
    var matches: [(NSRange, CodeToken)] = []
    for rule in rules {
        guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
        regex.enumerateMatches(in: code, range: fullRange) { result, _, _ in
            if let range = result?.range, range.length > 0 {
                matches.append((range, rule.token))
            }
        }
    }
    matches.sort { $0.0.location < $1.0.location }
    var deduped: [(NSRange, CodeToken)] = []
    var lastEnd = 0
    for (range, token) in matches {
        if range.location >= lastEnd {
            deduped.append((range, token))
            lastEnd = range.location + range.length
        }
    }

    var result = Text("")
    var cursor = 0
    for (range, token) in deduped {
        if range.location > cursor {
            let plainRange = NSRange(location: cursor, length: range.location - cursor)
            let chunk = nsCode.substring(with: plainRange)
            result = result + styled(chunk, color: CodePalette.plain)
        }
        let chunk = nsCode.substring(with: range)
        result = result + styled(chunk, color: color(for: token))
        cursor = range.location + range.length
    }
    if cursor < nsCode.length {
        let tail = nsCode.substring(from: cursor)
        result = result + styled(tail, color: CodePalette.plain)
    }
    return result
}

private func styled(_ text: String, color: Color) -> Text {
    Text(text)
        .font(.custom("JetBrains Mono", size: 14))
        .foregroundColor(color)
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

private enum SwiftHighlighter {
    static func highlight(_ code: String) -> Text {
        applyHighlighting(code, rules: swiftRules)
    }
}

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

private enum JavaScriptHighlighter {
    static func highlight(_ code: String) -> Text {
        applyHighlighting(code, rules: jsRules)
    }
}

private let jsonRules: [CodeRule] = [
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"\\s*:", token: .keyword),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "\\b(?:true|false|null)\\b", token: .keyword),
    CodeRule(pattern: "\\b-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", token: .number),
]

private enum JSONHighlighter {
    static func highlight(_ code: String) -> Text {
        applyHighlighting(code, rules: jsonRules)
    }
}

private let shellRules: [CodeRule] = [
    CodeRule(pattern: "#[^\n]*", token: .comment),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "'[^'\n]*'", token: .string),
    CodeRule(pattern: "\\$\\w+", token: .type),
    CodeRule(pattern: "\\$\\{[^}]+\\}", token: .type),
    CodeRule(pattern: "\\b(?:if|then|else|elif|fi|for|in|do|done|while|case|esac|function|return|exit|export|local|alias)\\b", token: .keyword),
]

private enum ShellHighlighter {
    static func highlight(_ code: String) -> Text {
        applyHighlighting(code, rules: shellRules)
    }
}

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

private enum PythonHighlighter {
    static func highlight(_ code: String) -> Text {
        applyHighlighting(code, rules: pythonRules)
    }
}

private let markupRules: [CodeRule] = [
    CodeRule(pattern: "<!--[\\s\\S]*?-->", token: .comment),
    CodeRule(pattern: "\"(?:[^\"\\\\\n]|\\\\.)*\"", token: .string),
    CodeRule(pattern: "'(?:[^'\\\\\n]|\\\\.)*'", token: .string),
    CodeRule(pattern: "</?[a-zA-Z][a-zA-Z0-9-]*", token: .keyword),
    CodeRule(pattern: "/?>", token: .keyword),
    CodeRule(pattern: "\\b(?:DOCTYPE|html|head|body|div|span|p|a|img|script|style|link|meta|title)\\b", token: .type),
]

private enum MarkupHighlighter {
    static func highlight(_ code: String) -> Text {
        applyHighlighting(code, rules: markupRules)
    }
}
