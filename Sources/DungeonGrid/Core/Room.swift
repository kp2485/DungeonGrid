//
//  Room.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct Room: Sendable, Equatable {
    public let id: Int
    public let rect: Rect
    public init(id: Int, rect: Rect) { self.id = id; self.rect = rect }
}