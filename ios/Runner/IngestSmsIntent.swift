import AppIntents
import Foundation

@available(iOS 16.0, *)
struct IngestSmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction from SMS"
    static var description = IntentDescription("Parses incoming bank and mobile money SMS messages and logs the transaction locally.")

    // CRITICAL: openAppWhenRun = false ensures headless background execution
    // The intent runs silently without launching or bringing Flutter UI to the foreground.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Message Text", description: "The incoming SMS or notification text body")
    var messageText: String

    @Parameter(title: "Sender", description: "The bank or mobile money sender ID (e.g. CBE, Telebirr, 127)")
    var sender: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log bank message \(\.$messageText) from \(\.$sender)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary = await NativeIngestionManager.shared.processIncoming(
            rawText: messageText,
            sender: sender
        )
        return .result(value: summary)
    }
}
