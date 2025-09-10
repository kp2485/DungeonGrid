//
//  Stamp.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 9/10/25.
//

import Foundation

// Canonical stamp tuple used across placement/external item APIs.
// IMPORTANT: All code should use this alias in function signatures.
public typealias Stamp = (a: Point, tiles: [Point], rid: RegionID?)
