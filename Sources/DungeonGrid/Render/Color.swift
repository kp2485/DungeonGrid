//
//  Color.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct RGBA: Sendable, Equatable {
    public var r: UInt8, g: UInt8, b: UInt8, a: UInt8
    @inline(__always) public init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}
