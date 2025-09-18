//
//  DungeonJSON.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

/// Versioned snapshot model for stable on-disk interchange.
/// Compact: tiles/edges are 2-bit packed to Base64.
public enum DungeonJSON {

    /// Current on-disk JSON format version.
    public static let currentVersion: Int = 1
    
    public struct Snapshot: Codable {
        public let version: Int
        public let width: Int
        public let height: Int
        public let seed: UInt64

        // Packed data
        public let tilesB64: String
        public let edgesHB64: String
        public let edgesVB64: String

        // Rooms
        public let rooms: [RoomSnap]

        // Optional metadata
        public let entrance: [Int]?
        public let exit: [Int]?
        public let doorTiles: [[Int]]?

        public init(version: Int = DungeonJSON.currentVersion,
                    width: Int,
                    height: Int,
                    seed: UInt64,
                    tilesB64: String,
                    edgesHB64: String,
                    edgesVB64: String,
                    rooms: [RoomSnap],
                    entrance: [Int]?,
                    exit: [Int]?,
                    doorTiles: [[Int]]?) {
            self.version = version
            self.width = width
            self.height = height
            self.seed = seed
            self.tilesB64 = tilesB64
            self.edgesHB64 = edgesHB64
            self.edgesVB64 = edgesVB64
            self.rooms = rooms
            self.entrance = entrance
            self.exit = exit
            self.doorTiles = doorTiles
        }
    }

    public struct RoomSnap: Codable {
        public let id: Int
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int
    }

    // MARK: - Encode

    public static func encode(_ d: Dungeon) throws -> Data {
        let w = d.grid.width, h = d.grid.height
        // Tiles row-major
        let tilesB64 = TileCodec.packBase64(d.grid.tiles)
        // Edges
        let edgesHB64 = EdgeCodec.packBase64(d.edges.h)
        let edgesVB64 = EdgeCodec.packBase64(d.edges.v)

        let rooms = d.rooms.map { RoomSnap(id: $0.id, x: $0.rect.x, y: $0.rect.y, width: $0.rect.width, height: $0.rect.height) }
        let entrance = d.entrance.map { [$0.x, $0.y] }
        let exit = d.exit.map { [$0.x, $0.y] }
        let doorTiles = d.doors.map { [$0.x, $0.y] }

        let snap = Snapshot(width: w, height: h, seed: d.seed,
                            tilesB64: tilesB64, edgesHB64: edgesHB64, edgesVB64: edgesVB64,
                            rooms: rooms, entrance: entrance, exit: exit, doorTiles: doorTiles)

        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(snap)
    }

    /// Pretty-printed encoder intended for human-readable diffs and fixtures.
    /// Produces stable key ordering like `encode(_:)`.
    public static func encodePretty(_ d: Dungeon) throws -> Data {
        let w = d.grid.width, h = d.grid.height
        let tilesB64 = TileCodec.packBase64(d.grid.tiles)
        let edgesHB64 = EdgeCodec.packBase64(d.edges.h)
        let edgesVB64 = EdgeCodec.packBase64(d.edges.v)
        let rooms = d.rooms.map { RoomSnap(id: $0.id, x: $0.rect.x, y: $0.rect.y, width: $0.rect.width, height: $0.rect.height) }
        let entrance = d.entrance.map { [$0.x, $0.y] }
        let exit = d.exit.map { [$0.x, $0.y] }
        let doorTiles = d.doors.map { [$0.x, $0.y] }
        let snap = Snapshot(width: w, height: h, seed: d.seed,
                            tilesB64: tilesB64, edgesHB64: edgesHB64, edgesVB64: edgesVB64,
                            rooms: rooms, entrance: entrance, exit: exit, doorTiles: doorTiles)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try enc.encode(snap)
    }

    // MARK: - Decode

    public static func decode(_ data: Data) throws -> Dungeon {
        let dec = JSONDecoder()
        let s = try dec.decode(Snapshot.self, from: data)

        // Version check (explicit)
        guard s.version == DungeonJSON.currentVersion else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unsupported snapshot version \(s.version); expected \(DungeonJSON.currentVersion)"
            ))
        }

        // Dimensions
        let w = s.width, h = s.height
        guard w > 0, h > 0 else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Invalid dimensions: width=\(w), height=\(h)"
            ))
        }

        // Quick Base64 length sanity (multiple of 4) for clearer error messages
        func assertBase64MultipleOf4(_ name: String, _ s: String) throws {
            if s.count % 4 != 0 {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "\(name) Base64 length must be multiple of 4 (got \(s.count))"
                ))
            }
        }

        try assertBase64MultipleOf4("tilesB64", s.tilesB64)
        try assertBase64MultipleOf4("edgesHB64", s.edgesHB64)
        try assertBase64MultipleOf4("edgesVB64", s.edgesVB64)

        // Tiles
        guard let tiles = TileCodec.unpackBase64(s.tilesB64, count: w*h) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Bad tiles Base64 or length mismatch (expected \(w*h))"
            ))
        }
        var grid = Grid(width: w, height: h, fill: .wall)
        for i in 0..<(w*h) {
            grid[i % w, i / w] = tiles[i]
        }

        // Edges (strict length checks)
        guard let hEdges = EdgeCodec.unpackBase64(s.edgesHB64, count: w*(h+1)) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Bad horizontal edges Base64 or length mismatch (expected \(w*(h+1)))"
            ))
        }
        guard let vEdges = EdgeCodec.unpackBase64(s.edgesVB64, count: (w+1)*h) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Bad vertical edges Base64 or length mismatch (expected \((w+1)*h))"
            ))
        }
        var edges = EdgeGrid(width: w, height: h, fill: .wall)
        edges.h = hEdges
        edges.v = vEdges

        // Rooms (bounds checks)
        // Validate unique room ids
        var seenRoomIds = Set<Int>()
        let rooms: [Room] = try s.rooms.map { snap in
            guard snap.width > 0, snap.height > 0 else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Room \(snap.id) has non-positive size (\(snap.width)×\(snap.height))"
                ))
            }
            let maxX = snap.x + snap.width  - 1
            let maxY = snap.y + snap.height - 1
            guard snap.x >= 0, snap.y >= 0, maxX < w, maxY < h else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Room \(snap.id) out of bounds: rect=(\(snap.x),\(snap.y),\(snap.width),\(snap.height)) grid=(\(w)×\(h))"
                ))
            }
            if !seenRoomIds.insert(snap.id).inserted {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [], debugDescription: "Duplicate room id: \(snap.id)"
                ))
            }
            return Room(id: snap.id, rect: Rect(x: snap.x, y: snap.y, width: snap.width, height: snap.height))
        }

        // Optional points (validate bounds when present)
        func decodePoint(_ arr: [Int]?) throws -> Point? {
            guard let a = arr else { return nil }
            guard a.count == 2 else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Point must be [x,y]"))
            }
            let p = Point(a[0], a[1])
            guard p.x >= 0, p.x < w, p.y >= 0, p.y < h else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [], debugDescription: "Point out of bounds: (\(p.x),\(p.y))"
                ))
            }
            return p
        }

        let entrance = try decodePoint(s.entrance)
        let exit      = try decodePoint(s.exit)

        // If S/E are present, ensure they are on passable tiles
        if let spt = entrance, grid[spt.x, spt.y].isPassable == false {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [], debugDescription: "Entrance not on a passable tile: (\(spt.x),\(spt.y))"
            ))
        }
        if let tpt = exit, grid[tpt.x, tpt.y].isPassable == false {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [], debugDescription: "Exit not on a passable tile: (\(tpt.x),\(tpt.y))"
            ))
        }

        // Optional door tiles (bounds-checked)
        let doors: [Point] = try (s.doorTiles ?? []).map { a in
            guard a.count == 2 else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Door tile must be [x,y]"))
            }
            let p = Point(a[0], a[1])
            guard p.x >= 0, p.x < w, p.y >= 0, p.y < h else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [], debugDescription: "Door tile out of bounds: (\(p.x),\(p.y))"
                ))
            }
            return p
        }

        return Dungeon(grid: grid,
                       rooms: rooms,
                       seed: s.seed,
                       doors: doors,
                       entrance: entrance,
                       exit: exit,
                       edges: edges)
    }
}
