import Testing
@testable import DungeonGrid

@Suite struct AlgorithmSwitchTests {
    @Test func bspWorks() {
        let cfg = DungeonConfig(width: 64, height: 40, algorithm: .bsp(BSPOptions()))
        let d = DungeonGrid.generate(config: cfg, seed: 1)
        #expect(d.grid.width == 64 && d.grid.height == 40)
        #expect(d.grid.tiles.contains(.floor))
    }

    @Test func mazeWorks() {
        let cfg = DungeonConfig(width: 41, height: 31, algorithm: .maze(MazeOptions()))
        let d = DungeonGrid.generate(config: cfg, seed: 2)
        #expect(d.grid.tiles.contains(.floor))
    }

    @Test func cavesWorks() {
        let cfg = DungeonConfig(width: 64, height: 40, algorithm: .caves(CavesOptions()))
        let d = DungeonGrid.generate(config: cfg, seed: 3)
        #expect(d.grid.tiles.contains(.floor))
    }

    @Test func uniformRoomsWorks() {
        let cfg = DungeonConfig(width: 80, height: 48, algorithm: .uniformRooms(UniformRoomsOptions()))
        let d = DungeonGrid.generate(config: cfg, seed: 4)
        #expect(d.grid.tiles.contains(.floor))
        #expect(!d.rooms.isEmpty)
    }
}
