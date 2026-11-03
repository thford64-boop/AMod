import SwiftUI
import UIKit

/// Lets SwiftUI insert snippets at the cursor.
final class EditorController: ObservableObject {
    weak var textView: UITextView?

    func insert(_ snippet: String) {
        guard let textView else { return }
        let text = textView.text ?? ""
        let location = textView.selectedRange.location
        let needsNewline = location > 0 && location <= (text as NSString).length
            && (text as NSString).substring(with: NSRange(location: location - 1, length: 1)) != "\n"
        textView.insertText((needsNewline ? "\n" : "") + snippet + "\n")
    }
}

/// A plain-text code editor: no smart quotes, auto-indent, light syntax colouring and a symbol bar.
struct CodeEditor: UIViewRepresentable {
    @Binding var text: String
    let controller: EditorController

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = Highlighter.font
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartQuotesType = .no
        tv.smartDashesType = .no
        tv.smartInsertDeleteType = .no
        tv.spellCheckingType = .no
        tv.alwaysBounceVertical = true
        tv.keyboardDismissMode = .interactive
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 40, right: 8)
        tv.backgroundColor = .systemBackground
        tv.inputAccessoryView = KeyBar.make(for: tv)
        tv.text = text
        Highlighter.apply(to: tv)
        controller.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        if tv.text != text {
            let selection = tv.selectedRange
            tv.text = text
            Highlighter.apply(to: tv)
            let length = (text as NSString).length
            tv.selectedRange = NSRange(location: min(selection.location, length), length: 0)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CodeEditor

        init(_ parent: CodeEditor) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            Highlighter.apply(to: tv)
            parent.text = tv.text
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement == "\n" else { return true }
            let ns = tv.text as NSString
            let lineStart = ns.lineRange(for: NSRange(location: range.location, length: 0)).location
            let line = ns.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
            var indent = String(line.prefix { $0 == " " || $0 == "\t" })
            if let last = line.trimmingCharacters(in: .whitespaces).last, "{([".contains(last) {
                indent += "  "
            }
            tv.insertText("\n" + indent)
            return false
        }
    }
}

enum Highlighter {
    static let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    private static let patterns: [(String, UIColor)] = [
        (#"\b(const|let|var|function|return|if|else|for|while|do|break|continue|new|class|extends|async|await|try|catch|finally|throw|switch|case|default|of|in|typeof|instanceof|true|false|null|undefined|this)\b"#, UIColor.systemPink),
        (#"\b(print|console|haptic|vibrate|flashlight|device|settings|clipboard|openURL|shortcuts|speak|notify|alert|confirm|input|ask|menu|share|location|http|fetchJSON|files|storage|calendar|reminders|scripts|require|ui|state|sleep|wait|exit|output|args|setTimeout|setInterval)\b"#, UIColor.systemTeal),
        (#"\b(VStack|HStack|ZStack|ScrollView|List|Form|Section|ForEach|Text|Button|Image|Label|Spacer|Divider|Toggle|Slider|Stepper|TextField|SecureField|Picker|ProgressView|Color|Link)\b"#, UIColor.systemIndigo),
        (#"\b\d+(\.\d+)?\b"#, UIColor.systemPurple),
        (#""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`"#, UIColor.systemRed),
        (#"//[^\n]*|/\*[\s\S]*?\*/"#, UIColor.systemGray),
    ]

    private static let rules: [(NSRegularExpression, UIColor)] = patterns.map { pattern, color in
        (try! NSRegularExpression(pattern: pattern), color)
    }

    static func apply(to tv: UITextView) {
        // Leave marked (IME) text alone or composition breaks.
        guard tv.markedTextRange == nil else { return }
        let storage = tv.textStorage
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: UIColor.label], range: full)
        for (regex, color) in rules {
            for match in regex.matches(in: text, range: full) {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        storage.endEditing()
        tv.typingAttributes = [.font: font, .foregroundColor: UIColor.label]
    }
}

enum KeyBar {
    static func make(for textView: UITextView) -> UIView {
        let bar = UIInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 46), inputViewStyle: .keyboard)
        bar.autoresizingMask = .flexibleWidth

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let keys = ["⇥", "(", ")", "{", "}", "[", "]", "\"", "'", "`", ";", "=", "=>", ".", ",", ":",
                    "!", "&&", "||", "+", "-", "*", "/", "<", ">", "$", "?", "_"]
        for key in keys {
            var config = UIButton.Configuration.gray()
            config.title = key
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            let button = UIButton(configuration: config, primaryAction: UIAction { [weak textView] _ in
                UIDevice.current.playInputClick()
                textView?.insertText(key == "⇥" ? "  " : key)
            })
            stack.addArrangedSubview(button)
        }

        var doneConfig = UIButton.Configuration.plain()
        doneConfig.image = UIImage(systemName: "keyboard.chevron.compact.down")
        let done = UIButton(configuration: doneConfig, primaryAction: UIAction { [weak textView] _ in
            textView?.resignFirstResponder()
        })
        done.translatesAutoresizingMaskIntoConstraints = false

        scroll.addSubview(stack)
        bar.addSubview(scroll)
        bar.addSubview(done)
        NSLayoutConstraint.activate([
            done.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -4),
            done.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            done.widthAnchor.constraint(equalToConstant: 44),
            scroll.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: done.leadingAnchor, constant: -4),
            scroll.topAnchor.constraint(equalTo: bar.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -6),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -12),
        ])
        return bar
    }
}
