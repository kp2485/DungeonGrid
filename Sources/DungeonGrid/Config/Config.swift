//
//  Config.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public struct DungeonConfig: Sendable {
    public var width: Int
    public var height: Int
    public var algorithm: Algorithm
    public var ensureConnected: Bool
    public var placeDoorsAndTags: Bool

    public init(
        width: Int,
        height: Int,
        algorithm: Algorithm = .bsp(BSPOptions()),
        ensureConnected: Bool = true,
        placeDoorsAndTags: Bool = true
    ) {
        precondition(width > 4 && height > 4, "Grid must be at least 5x5")
        self.width = width
        self.height = height
        self.algorithm = algorithm
        self.ensureConnected = ensureConnected
        self.placeDoorsAndTags = placeDoorsAndTags
    }
}
