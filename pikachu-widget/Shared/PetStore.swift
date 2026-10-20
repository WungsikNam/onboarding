import Foundation

/// Persists the pet in the shared App Group so the app, widgets and Live Activity all see the same Pikachu.
final class PetStore {
    static let shared = PetStore()

    private let defaults: UserDefaults
    private let stateKey = "pet.state.v1"
    private let statusBarKey = "pet.statusBarEnabled"

    init() {
        // Injected from the APP_GROUP_ID build setting (see project.yml).
        let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
        defaults = group.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The stored state, decayed up to `date`.
    func load(at date: Date = .now) -> PetState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(PetState.self, from: data)
        else { return PetState(now: date) }
        return state.advanced(to: date)
    }

    func save(_ state: PetState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }

    @discardableResult
    func apply(_ action: PetAction, at date: Date = .now) -> PetState {
        var state = load(at: date)
        state.apply(action, at: date)
        save(state)
        return state
    }

    @discardableResult
    func rename(_ name: String) -> PetState {
        var state = load()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        state.name = trimmed.isEmpty ? "피카츄" : String(trimmed.prefix(10))
        save(state)
        return state
    }

    @discardableResult
    func reset() -> PetState {
        let state = PetState(now: .now)
        save(state)
        return state
    }

    /// Whether the user wants Pikachu living in the Dynamic Island / Lock Screen.
    var statusBarEnabled: Bool {
        get { defaults.object(forKey: statusBarKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: statusBarKey) }
    }
}
