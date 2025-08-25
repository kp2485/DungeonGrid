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
        // 1) Base generation
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

        // 2) Compose post steps explicitly
        var pipe = DungeonPipeline(base: base)
        if config.ensureConnected {
            pipe = pipe.ensureConnected(seed: seed)
        }
        if config.placeDoorsAndTags {
            pipe = pipe.placeDoors(seed: seed)
        }

        // 3) Execute
        let result = pipe.run()
        return result.dungeon
    }
}
