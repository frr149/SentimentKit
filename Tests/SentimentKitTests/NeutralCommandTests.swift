import Testing
@testable import SentimentKit

struct NeutralCommandTests {
    @Test
    func approvedTechnicalCommandsStayNeutral() {
        let analyzer = SentimentAnalyzer()
        let commands = [
            "delete the temp file",
            "run make test",
            "commit and push",
            "borra el fichero temporal",
            "ejecuta los tests",
            "ok",
            "sí",
            "no",
            "usa .foregroundStyle(.tertiary)",
            "cambia el var por let",
            "git reset --hard",
            "kill the process",
            "nuke the cache",
            "drop the database",
            "abort the operation",
        ]

        for command in commands {
            let result = analyzer.analyze(command)
            #expect(abs(result.score) <= 0.1, "\(command) should stay neutral")
            #expect(result.profanity.isEmpty && result.frustration.isEmpty && result.positive.isEmpty)
        }
    }
}
