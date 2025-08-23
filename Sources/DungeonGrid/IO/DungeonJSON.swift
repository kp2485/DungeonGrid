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

        public init(version: Int = 1,
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
        enc.outputFormatting = [.withoutEscapingSlashes]
        return try enc.encode(snap)
    }

    // MARK: - Decode

    public static func decode(_ data: Data) throws -> Dungeon {
        let dec = JSONDecoder()
        let s = try dec.decode(Snapshot.self, from: data)
        guard s.version == 1 else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unsupported snapshot version \(s.version)")) }

        let w = s.width, h = s.height
        // Tiles
        guard let tiles = TileCodec.unpackBase64(s.tilesB64, count: w*h) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad tiles Base64"))
        }
        var grid = Grid(width: w, height: h, fill: .wall)
        for i in 0..<(w*h) {
            let x = i % w, y = i / w
            grid[x, y] = tiles[i]
        }

        // Edges
        guard let hEdges = EdgeCodec.unpackBase64(s.edgesHB64, count: w*(h+1)),
              let vEdges = EdgeCodec.unpackBase64(s.edgesVB64, count: (w+1)*h) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Bad edges Base64"))
        }
        var edges = EdgeGrid(width: w, height: h, fill: .wall)
        edges.h = hEdges
        edges.v = vEdges

        // Rooms
        let rooms = s.rooms.map { Room(id: $0.id, rect: Rect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)) }

        // Optional points
        let entrance = s.entrance.flatMap { $0.count == 2 ? Point($0[0], $0[1]) : nil }
        let exit = s.exit.flatMap { $0.count == 2 ? Point($0[0], $0[1]) : nil }
        let doors: [Point] = s.doorTiles?.compactMap { $0.count == 2 ? Point($0[0], $0[1]) : nil } ?? []

        return Dungeon(grid: grid, rooms: rooms, seed: s.seed,
                       doors: doors, entrance: entrance, exit: exit,
                       edges: edges)
    }
}