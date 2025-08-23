//
//  Algorithm.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public enum Algorithm: Sendable, Equatable {
    case bsp(BSPOptions)
    case maze(MazeOptions)
    case caves(CavesOptions)
    case uniformRooms(UniformRoomsOptions)
}