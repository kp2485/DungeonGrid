//
//  BSPOptions.swift
//  DungeonGrid
//
//  Created by Kyle Peterson on 8/23/25.
//


import Foundation

public struct BSPOptions: Sendable, Equatable {
    public var minLeafSize: Int = 8
    public var maxLeafSize: Int = 16
    public var roomMinSize: Int = 3
    public var roomMaxSize: Int = 8
    public var keepOuterBorder: Bool = true

    public init() {}
}