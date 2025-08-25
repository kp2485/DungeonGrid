//
//  DungeonPipelineMetrics.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/25/25.
//
//  Aggregated timing + counts for a DungeonPipeline run.
//

import Foundation

public struct DungeonPipelineMetrics: Sendable {
    public struct Step: Sendable {
        public let name: String
        public let durationMS: Double
        public init(name: String, durationMS: Double) {
            self.name = name
            self.durationMS = durationMS
        }
    }

    public struct Totals: Sendable {
        public let width: Int
        public let height: Int
        public let tilesWall: Int
        public let tilesFloor: Int
        public let tilesDoor: Int
        public let doorEdgesH: Int
        public let doorEdgesV: Int
        public let rooms: Int
        public let placementsByKind: [String: Int]

        public init(width: Int,
                    height: Int,
                    tilesWall: Int,
                    tilesFloor: Int,
                    tilesDoor: Int,
                    doorEdgesH: Int,
                    doorEdgesV: Int,
                    rooms: Int,
                    placementsByKind: [String: Int]) {
            self.width = width
            self.height = height
            self.tilesWall = tilesWall
            self.tilesFloor = tilesFloor
            self.tilesDoor = tilesDoor
            self.doorEdgesH = doorEdgesH
            self.doorEdgesV = doorEdgesV
            self.rooms = rooms
            self.placementsByKind = placementsByKind
        }
    }

    public let steps: [Step]
    public let totals: Totals

    public init(steps: [Step], totals: Totals) {
        self.steps = steps
        self.totals = totals
    }
}
