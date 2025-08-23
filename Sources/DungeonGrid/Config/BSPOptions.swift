//
//  BSPOptions.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct BSPOptions: Sendable, Equatable {
    public var minLeafSize: Int = 12
    public var maxLeafSize: Int = 24
    public var roomMinSize: Int = 5
    public var roomMaxSize: Int = 12
    public var keepOuterBorder: Bool = true

    public init() {}
}