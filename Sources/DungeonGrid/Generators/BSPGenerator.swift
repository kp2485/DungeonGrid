//
//  BSPGenerator.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//

import Foundation

final class BSPNode {
    let rect: Rect
    var left: BSPNode?
    var right: BSPNode?
    var room: Rect?

    init(rect: Rect) { self.rect = rect }
    var isLeaf: Bool { left == nil && right == nil }
}

struct BSPGenerator {
    let options: BSPOptions

    mutating func generate(width: Int, height: Int, seed: UInt64) -> Dungeon {
        var rng = SplitMix64(seed: seed)
        var grid = Grid(width: width, height: height, fill: .wall)

        // Build BSP
        let root = BSPNode(rect: Rect(x: 0, y: 0, width: width, height: height))
        split(node: root, rng: &rng)

        // Place rooms in leaves
        var rooms: [Room] = []
        var nextID = 0
        createRooms(node: root, rooms: &rooms, nextID: &nextID, rng: &rng)

        // ✅ Fallback: guarantee at least one room
        if rooms.isEmpty {
            let rw = min(options.roomMaxSize, max(3, width  / 3))
            let rh = min(options.roomMaxSize, max(3, height / 3))
            let rx = max(1, (width  - rw) / 2)
            let ry = max(1, (height - rh) / 2)
            let rect = Rect(x: rx, y: ry, width: rw, height: rh)
            rooms.append(Room(id: nextID, rect: rect))
            nextID += 1
        }

        // Connect sibling leaves with corridors (may be a no-op if only one room was placed)
        connect(node: root, grid: &grid, rng: &rng)

        // Carve rooms
        for r in rooms { carveRoom(r.rect, in: &grid) }

        if options.keepOuterBorder { keepOuterWalls(in: &grid) }

        // Build edge layer (truth for walls/doors)
        let edges = BuildEdges.fromGrid(grid)

        return Dungeon(
            grid: grid,
            rooms: rooms,
            seed: seed,
            doors: [],
            entrance: nil,
            exit: nil,
            edges: edges
        )
    }

    private func split(node: BSPNode, rng: inout SplitMix64) {
        let r = node.rect
        let canSplitHoriz = r.height >= options.minLeafSize * 2
        let canSplitVert  = r.width  >= options.minLeafSize * 2
        if !canSplitHoriz && !canSplitVert { return }

        let splitVert: Bool
        if canSplitVert && !canSplitHoriz { splitVert = true }
        else if !canSplitVert && canSplitHoriz { splitVert = false }
        else {
            let biasVert = r.width > r.height
            splitVert = rng.bool(biasVert ? 0.7 : 0.3)
        }

        if splitVert {
            let minX = r.x + options.minLeafSize
            let maxX = r.x + r.width - options.minLeafSize
            guard maxX - minX >= 1 else { return }
            let cutX = rng.int(in: minX...maxX)
            node.left = BSPNode(rect: Rect(x: r.x, y: r.y, width: cutX - r.x, height: r.height))
            node.right = BSPNode(rect: Rect(x: cutX, y: r.y, width: r.x + r.width - cutX, height: r.height))
        } else {
            let minY = r.y + options.minLeafSize
            let maxY = r.y + r.height - options.minLeafSize
            guard maxY - minY >= 1 else { return }
            let cutY = rng.int(in: minY...maxY)
            node.left = BSPNode(rect: Rect(x: r.x, y: r.y, width: r.width, height: cutY - r.y))
            node.right = BSPNode(rect: Rect(x: r.x, y: cutY, width: r.width, height: r.y + r.height - cutY))
        }

        if let l = node.left, (l.rect.width > options.maxLeafSize || l.rect.height > options.maxLeafSize) {
            split(node: l, rng: &rng)
        }
        if let r = node.right, (r.rect.width > options.maxLeafSize || r.rect.height > options.maxLeafSize) {
            split(node: r, rng: &rng)
        }
    }

    private func createRooms(node: BSPNode, rooms: inout [Room], nextID: inout Int, rng: inout SplitMix64) {
        
        if node.isLeaf {
            let bounds = node.rect.inset(dx: 1, dy: 1)
            let wMin = min(options.roomMinSize, bounds.width)
            let hMin = min(options.roomMinSize, bounds.height)
            let wMax = min(options.roomMaxSize, bounds.width)
            let hMax = min(options.roomMaxSize, bounds.height)
            guard wMin > 1 && hMin > 1 else { return }

            let rw = rng.int(in: wMin...max(wMin, wMax))
            let rh = rng.int(in: hMin...max(hMin, hMax))
            let rx = rng.int(in: bounds.x...(bounds.x + bounds.width - rw))
            let ry = rng.int(in: bounds.y...(bounds.y + bounds.height - rh))
            let rect = Rect(x: rx, y: ry, width: rw, height: rh)

            node.room = rect
            rooms.append(Room(id: nextID, rect: rect))
            nextID += 1
        } else {
            if let l = node.left { createRooms(node: l, rooms: &rooms, nextID: &nextID, rng: &rng) }
            if let r = node.right { createRooms(node: r, rooms: &rooms, nextID: &nextID, rng: &rng) }
        }
    }

    private func connect(node: BSPNode, grid: inout Grid, rng: inout SplitMix64) {
        guard let left = node.left, let right = node.right else { return }
        connect(node: left, grid: &grid, rng: &rng)
        connect(node: right, grid: &grid, rng: &rng)

        guard let a = findRoom(node: left, rng: &rng),
              let b = findRoom(node: right, rng: &rng) else { return }

        let aPoint = (x: a.midX, y: a.midY)
        let bPoint = (x: b.midX, y: b.midY)

        if rng.bool() {
            carveH(min(aPoint.x, bPoint.x), max(aPoint.x, bPoint.x), aPoint.y, &grid)
            carveV(min(aPoint.y, bPoint.y), max(aPoint.y, bPoint.y), bPoint.x, &grid)
        } else {
            carveV(min(aPoint.y, bPoint.y), max(aPoint.y, bPoint.y), aPoint.x, &grid)
            carveH(min(aPoint.x, bPoint.x), max(aPoint.x, bPoint.x), bPoint.y, &grid)
        }
    }

    private func findRoom(node: BSPNode, rng: inout SplitMix64) -> Rect? {
        if let r = node.room { return r }
        var candidates: [Rect] = []
        if let l = node.left, let lr = findRoom(node: l, rng: &rng) { candidates.append(lr) }
        if let r = node.right, let rr = findRoom(node: r, rng: &rng) { candidates.append(rr) }
        guard !candidates.isEmpty else { return nil }
        let idx = rng.int(in: 0...(candidates.count - 1))
        return candidates[idx]
    }

    private func carveRoom(_ r: Rect, in grid: inout Grid) {
        for y in r.minY...r.maxY {
            for x in r.minX...r.maxX { grid[x, y] = .floor }
        }
    }

    private func keepOuterWalls(in grid: inout Grid) {
        for x in 0..<grid.width {
            grid[x, 0] = .wall
            grid[x, grid.height - 1] = .wall
        }
        for y in 0..<grid.height {
            grid[0, y] = .wall
            grid[grid.width - 1, y] = .wall
        }
    }
}
