import AppIntents
import Foundation

/// Shows up in the Shortcuts app as "Run AMod Script". Runs without opening AMod
/// and hands back what the script printed (or passed to `output()`), so scripts can
/// be chained with any other Shortcuts action — automations included.
struct RunScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "Run AMod Script"
    static var description = IntentDescription(
        "Runs an AMod script in the background and returns its output. Prompts and GUI are skipped; use “Open AMod Script” for those."
    )

    @Parameter(title: "Script Name")
    var name: String

    @Parameter(title: "Input", default: "")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$name) with \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let name = self.name
        let script = await MainActor.run { ScriptStore.shared.script(named: name) }
        guard let script else {
            return .result(value: "AMod: no script named \"\(name)\"")
        }
        let output = await HeadlessRunner.run(script, input: input)
        return .result(value: output)
    }
}

/// Opens AMod and runs a script with its full UI (alerts, inputs, GUI).
struct OpenScriptIntent: AppIntent {
    static var title: LocalizedStringResource = "Open AMod Script"
    static var description = IntentDescription("Opens AMod and runs a script with its full interface.")
    static var openAppWhenRun = true

    @Parameter(title: "Script Name")
    var name: String

    @Parameter(title: "Input", default: "")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$name) with \(\.$input)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let script = ScriptStore.shared.script(named: name) {
            Router.shared.run(script, input: input)
        }
        return .result()
    }
}
