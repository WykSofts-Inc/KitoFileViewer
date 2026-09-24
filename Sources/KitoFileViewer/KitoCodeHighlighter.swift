//
//  KitoCodeHighlighter.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// A light, line-by-line highlighter for the code viewer: keywords, strings, numbers and comments.
///
/// It is deliberately simple — no parsing — so it is fast on long files and never wrong in a
/// way that hides text. Block comments and multi-line strings are not tracked across lines.
public enum KitoCodeHighlighter {
    public enum TokenKind: Hashable, Sendable {
        case keyword, string, number, comment
    }

    public struct Token: Hashable, Sendable {
        /// Character offsets in the line.
        public var range: Range<Int>
        public var kind: TokenKind

        public init(range: Range<Int>, kind: TokenKind) {
            self.range = range
            self.kind = kind
        }
    }

    /// Keywords for common languages, picked by file extension.
    public static func keywords(forExtension ext: String) -> Set<String> {
        switch ext.lowercased() {
        case "swift":
            return ["import", "struct", "class", "enum", "protocol", "extension", "func", "var", "let",
                    "if", "else", "guard", "return", "switch", "case", "default", "for", "in", "while",
                    "public", "private", "internal", "fileprivate", "static", "self", "Self", "init",
                    "some", "any", "async", "await", "throws", "try", "true", "false", "nil", "where",
                    "mutating", "final", "override", "@State", "@Binding", "@Observable", "@MainActor"]
        case "json":
            return ["true", "false", "null"]
        case "py":
            return ["def", "class", "import", "from", "return", "if", "elif", "else", "for", "in",
                    "while", "with", "as", "True", "False", "None", "lambda", "async", "await"]
        default:
            return ["function", "const", "let", "var", "if", "else", "return", "for", "while", "class",
                    "import", "export", "from", "true", "false", "null", "new", "this", "async", "await"]
        }
    }

    /// Whether files with this extension get highlighting.
    public static func highlights(extension ext: String) -> Bool {
        KitoFileKind.detect(pathExtension: ext) == .code
    }

    /// Whether `#` starts a comment for this extension (Python, shell, YAML, Ruby).
    public static func usesHashComments(extension ext: String) -> Bool {
        ["py", "sh", "yml", "yaml", "rb"].contains(ext.lowercased())
    }

    /// The tokens in one line, in order and never overlapping.
    /// - Parameter hashComments: Whether `#` starts a comment, as in Python or shell.
    public static func tokens(in line: String, keywords: Set<String>, hashComments: Bool = false) -> [Token] {
        let chars = Array(line)
        var tokens: [Token] = []
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if isCommentStart(chars, at: index, hashComments: hashComments) {
                tokens.append(Token(range: index..<chars.count, kind: .comment))
                break
            }
            if char == "\"" || char == "'" {
                let end = stringEnd(chars, from: index, quote: char)
                tokens.append(Token(range: index..<end, kind: .string))
                index = end
                continue
            }
            if char.isNumber, index == 0 || !isWordCharacter(chars[index - 1]) {
                var end = index
                while end < chars.count, chars[end].isNumber || chars[end] == "." || chars[end] == "_" { end += 1 }
                tokens.append(Token(range: index..<end, kind: .number))
                index = end
                continue
            }
            if isWordCharacter(char) || char == "@" {
                var end = index + 1
                while end < chars.count, isWordCharacter(chars[end]) { end += 1 }
                if keywords.contains(String(chars[index..<end])) {
                    tokens.append(Token(range: index..<end, kind: .keyword))
                }
                index = end
                continue
            }
            index += 1
        }
        return tokens
    }

    private static func isCommentStart(_ chars: [Character], at index: Int, hashComments: Bool) -> Bool {
        if chars[index] == "#" { return hashComments && (index == 0 || chars[index - 1].isWhitespace) }
        guard chars[index] == "/", index + 1 < chars.count else { return false }
        return chars[index + 1] == "/" || chars[index + 1] == "*"
    }

    private static func stringEnd(_ chars: [Character], from start: Int, quote: Character) -> Int {
        var index = start + 1
        while index < chars.count {
            if chars[index] == "\\" { index += 2; continue }
            if chars[index] == quote { return index + 1 }
            index += 1
        }
        return chars.count
    }

    private static func isWordCharacter(_ char: Character) -> Bool {
        char.isLetter || char.isNumber || char == "_"
    }
}
