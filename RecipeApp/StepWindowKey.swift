import Foundation
import SwiftData

struct StepWindowKey: Codable, Hashable {
    let stepID: PersistentIdentifier
    let instanceID: UUID
    
    init(stepID: PersistentIdentifier, instanceID: UUID = UUID()) {
        self.stepID = stepID
        self.instanceID = instanceID
    }
    
    // Each window instance is unique (different instanceID = different window)
    // This allows multiple windows for different steps, and reopening closed windows
}

