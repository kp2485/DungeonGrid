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
    public let type: RoomType
    
    public init(id: Int, rect: Rect, type: RoomType = .normal) { 
        self.id = id; self.rect = rect; self.type = type 
    }
}

public enum RoomType: Sendable, Equatable {
    case normal
    case closet
}