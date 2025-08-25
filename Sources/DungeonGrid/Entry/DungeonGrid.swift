//
//  DungeonGrid.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

public enum DungeonGrid {
    
    /// Base generation entry point.
    /// Applies `ensureConnected` and `placeDoorsAndTags` when enabled in `config`
    /// to match test expectations (entrance/exit present when appropriate).
    public static func generate(config: DungeonConfig, seed: UInt64) -> Dungeon {
        // 1) Base
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
        
        // 2) Honor config flags (keeps generate() convenient for tests)
        var d = base
        if config.ensureConnected {
            d = Connectivity.ensureConnected(d, seed: seed)
        }
        if config.placeDoorsAndTags {
            d = EdgeDoors.placeDoorsAndTag(d, seed: seed)
        }
        return d
    }
    
    /// High-level generation with optional post steps and **batch placement**.
    ///
    /// Steps default to using the same `seed` unless you provide per-kind seeds in `requests`.
    /// - Parameters:
    ///   - config: base generation config (width/height/algorithm flags)
    ///   - seed: master seed used for base generation and defaulted across steps
    ///   - ensureConnected: run connectivity pass (defaults to `config.ensureConnected`)
    ///   - placeDoorsAndTags: run door placement + entrance/exit tagging (defaults to `config.placeDoorsAndTags`)
    ///   - doorPolicy: rasterization policy for door tiles/edges
    ///   - locks: optional locks planning parameters
    ///   - themes: optional theming rules and a seed offset
    ///   - requests: batch placement requests (kind/policy/seed)
    /// - Returns: full pipeline result (dungeon + placements + optional plans/themes + metrics)
    public static func generateFull(
        config: DungeonConfig,
        seed: UInt64,
        ensureConnected: Bool? = nil,
        placeDoorsAndTags: Bool? = nil,
        doorPolicy: DoorPolicy = .init(),
        locks: (maxLocks: Int, doorBias: Int)? = nil,
        themes: (rules: [ThemeRule], seedOffset: UInt64)? = nil,
        requests: [PlacementRequest]
    ) -> DungeonPipelineResult {
        
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
        
        // 2) Compose pipeline
        var pipe = DungeonPipeline(base: base)
        
        if (ensureConnected ?? config.ensureConnected) {
            pipe = pipe.ensureConnected(seed: SeedDeriver.derive(seed, "ensureConnected"))
        }
        if (placeDoorsAndTags ?? config.placeDoorsAndTags) {
            pipe = pipe.placeDoors(seed: SeedDeriver.derive(seed, "placeDoorsAndTag"),
                                   policy: doorPolicy)
        }
        if let l = locks {
            pipe = pipe.planLocks(maxLocks: l.maxLocks, doorBias: l.doorBias)
        }
        if let t = themes {
            // combine a named derivation with caller’s offset for theming independence
            let sTheme = SeedDeriver.derive(seed, "theme") &+ t.seedOffset
            pipe = pipe.theme(seed: sTheme, rules: t.rules)
        }
        if !requests.isEmpty {
            pipe = pipe.placeAll(requests) // each request carries its own seed
        }
        
        // 3) Run and return
        return pipe.run()
    }
}
