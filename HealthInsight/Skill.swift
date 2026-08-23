import Foundation

struct ActionParam {
    let name: String
    let description: String
    let required: Bool

    init(_ name: String, _ description: String, required: Bool = true) {
        self.name = name
        self.description = description
        self.required = required
    }
}

struct Action {
    let name: String
    let description: String
    let params: [ActionParam]
    let execute: ([String: String]) async -> String
}

struct Skill {
    let name: String
    let description: String
    let actions: [Action]
}
