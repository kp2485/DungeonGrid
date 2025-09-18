//
//  UniformRoomsOptions.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct UniformRoomsOptions: Sendable, Equatable {
    public var attempts: Int = 150
    public var roomMin: (w: Int, h: Int) = (3, 3)
    public var roomMax: (w: Int, h: Int) = (6, 5)
    public var separation: Int = 1

    public init() {}
}

// Keep the custom equality here (only here).
public extension UniformRoomsOptions {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.attempts == rhs.attempts &&
        lhs.roomMin.w == rhs.roomMin.w &&
        lhs.roomMin.h == rhs.roomMin.h &&
        lhs.roomMax.w == rhs.roomMax.w &&
        lhs.roomMax.h == rhs.roomMax.h &&
        lhs.separation == rhs.separation
    }
}
