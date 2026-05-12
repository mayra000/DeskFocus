//
//  DeskStorage.swift
//  DeskFocus
//

import Foundation

protocol DeskStorage {
    func load() -> SessionState
    func save(_ state: SessionState)
}
