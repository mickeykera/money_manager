import Foundation
import CryptoKit

public class NativeIngestionManager {
    public static final let shared = NativeIngestionManager()
    
    private let appGroupIdentifier = "group.com.ledgerleaf.app"
    private let eventsFileName = "ingestion_events.json"
    private let fileQueue = DispatchQueue(label: "com.ledgerleaf.native_ingestion_queue")
    
    private init() {}
    
    /// Processes incoming SMS message received from AppIntent in background
    public func processIncoming(rawText: String, sender: String?) async -> String {
        let cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty {
            return "LedgerLeaf: Empty message ignored."
        }
        
        // 1. Guardrail against OTPs & Passcodes
        if isOtp(text: cleanText) {
            return "LedgerLeaf: Security passcode / OTP ignored and discarded."
        }
        
        // 2. Guardrail against failed transactions
        if isFailedTxn(text: cleanText) {
            return "LedgerLeaf: Failed or declined transaction alert ignored."
        }
        
        // 3. Create persistent event payload
        let event = IngestionEvent(
            id: UUID().uuidString,
            rawText: cleanText,
            sender: sender ?? "Unknown",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            fingerprint: computeSha256(input: "\(sender ?? "")|\(cleanText)")
        )
        
        // 4. Persist to App Group Container queue
        let persisted = writeEventToAppGroup(event: event)
        if persisted {
            return "LedgerLeaf: Transaction queued for local ledger."
        } else {
            return "LedgerLeaf: Processed in memory."
        }
    }
    
    private func isOtp(text: String) -> Bool {
        let patterns = [
            "\\b(otp|one-time\\s+password|passcode)\\b",
            "\\b(verification\\s+code|security\\s+code)\\b",
            "\\b(do\\s+not\\s+share|never\\s+share)\\b",
            "ሚስጥራዊ\\s*ቁጥር",
            "ይህንን\\s*ቁጥር\\s*ለማንም\\s*አያጋሩ"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil {
                return true
            }
        }
        return false
    }
    
    private func isFailedTxn(text: String) -> Bool {
        let patterns = [
            "\\b(transaction\\s+failed|declined|insufficient\\s+funds)\\b",
            "አልተሳካም",
            "በቂ\\s*ቀሪ\\s*ገንዘብ\\s*የለም"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) != nil {
                return true
            }
        }
        return false
    }
    
    private func computeSha256(input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func writeEventToAppGroup(event: IngestionEvent) -> Bool {
        return fileQueue.sync {
            guard let containerUrl = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupIdentifier
            ) else {
                // If App Group is not provisioned (e.g. running outside simulator with free account), fallback to Documents
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                return appendToFile(directory: docs, event: event)
            }
            return appendToFile(directory: containerUrl, event: event)
        }
    }
    
    private func appendToFile(directory: URL?, event: IngestionEvent) -> Bool {
        guard let directory = directory else { return false }
        let fileUrl = directory.appendingPathComponent(eventsFileName)
        
        var existingList: [IngestionEvent] = []
        if FileManager.default.fileExists(atPath: fileUrl.path),
           let data = try? Data(contentsOf: fileUrl),
           let decoded = try? JSONDecoder().decode([IngestionEvent].self, from: data) {
            existingList = decoded
        }
        
        existingList.append(event)
        
        guard let encoded = try? JSONEncoder().encode(existingList) else { return false }
        
        do {
            try encoded.write(to: fileUrl, options: [.atomic])
            // Set file protection so background App Intent can write while phone is locked after first unlock
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileUrl.path
            )
            return true
        } catch {
            return false
        }
    }
}

public struct IngestionEvent: Codable {
    public let id: String
    public let rawText: String
    public let sender: String
    public let timestamp: String
    public let fingerprint: String
}
