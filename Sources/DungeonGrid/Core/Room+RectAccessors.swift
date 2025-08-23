//
//  Room+RectAccessors.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

public extension Room {
    var minX: Int { rect.minX }
    var minY: Int { rect.minY }
    var maxX: Int { rect.maxX }
    var maxY: Int { rect.maxY }
    var midX: Int { rect.midX }
    var midY: Int { rect.midY }
    func contains(_ x: Int, _ y: Int) -> Bool { rect.contains(x, y) }
}
