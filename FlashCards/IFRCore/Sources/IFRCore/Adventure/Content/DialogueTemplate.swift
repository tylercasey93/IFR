import Foundation

public enum DialogueTemplate {
    public static func filled(_ script: DialogueScript, with values: [String: String]) -> DialogueScript {
        DialogueScript(pages: script.pages.map { filled($0, with: values) })
    }

    private static func filled(_ page: String, with values: [String: String]) -> String {
        values.reduce(page) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }
}
