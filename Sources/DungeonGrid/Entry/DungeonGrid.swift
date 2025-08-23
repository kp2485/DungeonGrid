//
//  DungeonGrid.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public enum DungeonGrid {
    @discardableResult
    public static func generate(config: DungeonConfig, seed: UInt64) -> Dungeon {
        let base: Dungeon

        switch config.algorithm {
        case .bsp(let opts):
            var g = BSPGenerator(options: opts)
            base = g.generate(width: config.width, height: config.height, seed: seed)

        case .maze(let opts):
            var g = MazeGenerator(options: opts)
            base = g.generate(width: config.width, height: config.height, seed: seed)

        case .caves(let opts):
            var g = CavesGenerator(options: opts)
            base = g.generate(width: config.width, height: config.height, seed: seed)

        case .uniformRooms(let opts):
            var g = UniformRoomsGenerator(options: opts)
            base = g.generate(width: config.width, height: config.height, seed: seed)
        }

        var out = base
        if config.ensureConnected {
            out = Connectivity.ensureConnected(out, seed: seed)
        }
        if config.placeDoorsAndTags {
            out = EdgeDoors.placeDoorsAndTag(out, seed: seed)
        }
        return out
    }
}
