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
    
    /// Generate a dungeon and (optionally) run common post steps via a single call.
    ///
    /// - Parameters:
    ///   - config: base generation config
    ///   - seed: base seed used for all steps (you can offset per step below)
    ///   - ensureConnected: run connectivity pass (default: config.ensureConnected)
    ///   - placeDoorsAndTags: run door placement + entrance/exit tagging (default: config.placeDoorsAndTags)
    ///   - doorPolicy: door rasterization policy (optional; default .init())
    ///   - locks: optional locks plan parameters; when provided, runs LocksPlanner
    ///   - themes: optional tuple (rules, seedOffset) to run Themer
    ///   - placements: optional list of (kind, policy, seedOffset) to plan placements
    ///
    /// - Returns: DungeonPipelineResult (dungeon + optional locks, themes, placements)
    
    public static func generateFull(
        config: DungeonConfig,
        seed: UInt64,
        ensureConnected: Bool? = nil,
        placeDoorsAndTags: Bool? = nil,
        doorPolicy: DoorPolicy = .init(),
        locks: (maxLocks: Int, doorBias: Int)? = nil,
        themes: (rules: [ThemeRule], seedOffset: UInt64)? = nil,
        placements: [(kind: String, policy: PlacementPolicy, seedOffset: UInt64)] = []
    ) -> DungeonPipelineResult {
        
        // 1) Base generation (same as generate)
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
        
        // 2) Compose a pipeline (use base seed unless an explicit offset is provided)
        var pipe = DungeonPipeline(base: base)
        
        if (ensureConnected ?? config.ensureConnected) {
            pipe = pipe.ensureConnected(seed: seed)
        }
        if (placeDoorsAndTags ?? config.placeDoorsAndTags) {
            pipe = pipe.placeDoors(seed: seed, policy: doorPolicy)
        }
        if let l = locks {
            pipe = pipe.planLocks(maxLocks: l.maxLocks, doorBias: l.doorBias)
        }
        if let t = themes {
            pipe = pipe.theme(seed: seed &+ t.seedOffset, rules: t.rules)
        }
        for p in placements {
            pipe = pipe.place(kind: p.kind, policy: p.policy, seed: seed &+ p.seedOffset)
        }
        
        // 3) Run and return the full result
        return pipe.run()
    }
}
