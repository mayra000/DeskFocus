//
//  LocalDeskStorage.swift
//  DeskFocus
//

import Foundation

struct LocalDeskStorage: DeskStorage {
    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func load() -> SessionState {
        guard let data = defaults.data(forKey: SessionState.storageKey) else {
            return .default
        }
        guard let decoded = try? JSONDecoder().decode(SessionState.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save(_ state: SessionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: SessionState.storageKey)
    }
}
