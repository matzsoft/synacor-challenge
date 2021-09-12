//
//  Vault.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 9/11/21.
//

import Foundation

enum Node: CustomStringConvertible {
    case start
    case value( Int )
    case operation( ( Int, Int ) -> Int )
    case target( Int )
    
    var description: String {
        switch self {
        case .start:
            return " A"
        case .value( let value ):
            return String( format: "%2d", value )
        case .target( _ ):
            return " V"
        case .operation( let operation ):
            switch operation( 0, 1 ) {
            case 1:
                return " +"
            case -1:
                return " -"
            case 0:
                return " *"
            default:
                return " ?"
            }
        }
    }
}


struct Position: Hashable {
    let x: Int
    let y: Int
    
    func distance( other: Position ) -> Int {
        return abs( x - other.x ) + abs( y - other.y )
    }
    
    static func +( left: Position, right: Position ) -> Position {
        return Position( x: left.x + right.x, y: left.y + right.y )
    }
    
    static func -( left: Position, right: Position ) -> Position {
        return Position( x: left.x - right.x, y: left.y - right.y )
    }
    
    static func ==( left: Position, right: Position ) -> Bool {
        return left.x == right.x && left.y == right.y
    }
}


enum Direction: String, CaseIterable, CustomStringConvertible {
    case north, east, south, west
    
    var description: String { rawValue }
    
    var vector: Position {
        switch self {
        case .north:
            return Position( x: 0, y: 1 )
        case .east:
            return Position( x: 1, y: 0 )
        case .south:
            return Position( x: 0, y: -1 )
        case .west:
            return Position( x: -1, y: 0 )
        }
    }
}


struct Vault: CustomStringConvertible {
    let initialWeight = 22
    let targetWeight = 30
    let map: [[Node]]
    
    var description: String {
        map.map { $0.map { return "\($0)" }.joined( separator: " " ) }.reversed().joined( separator: "\n" )
    }
    
    init() {
        map = [
            [ Node.start,          Node.operation( - ), Node.value( 9 ),     Node.operation( * ) ],
            [ Node.operation( + ), Node.value( 4 ),     Node.operation( - ), Node.value( 18 )    ],
            [ Node.value( 4 ),     Node.operation( * ), Node.value( 11 ),    Node.operation( * ) ],
            [ Node.operation( * ), Node.value( 8 ),     Node.operation( - ), Node.target( 1 )    ]
        ]
    }
    
    subscript( position: Position ) -> Node? {
        guard 0 <= position.x && position.x < map[0].count else { return nil }
        guard 0 <= position.y && position.y < map.count    else { return nil }
        return map[position.y][position.x]
    }
    
    func findShortestPath() -> [Direction] {
        struct QueueEntry {
            let position: Position
            let path: [Direction]
            let weight: Int
            
            init( _ position: Position, _ path: [Direction], _ weight: Int) {
                self.position = position
                self.path = path
                self.weight = weight
            }
        }

        var queue = [ QueueEntry( Position( x: 0, y: 0 ), [], initialWeight ) ]
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let currentNode = self[ current.position ]
            
            for direction in Direction.allCases.filter( { self[ current.position + $0.vector ] != nil } ) {
                let nextPosition = current.position + direction.vector
                let nextNode = self[nextPosition]!
                
                switch nextNode {
                case .start:
                    break
                case .operation( _ ):
                    queue.append( QueueEntry( nextPosition, current.path + [ direction ], current.weight ) )
                case .value( let value ):
                    guard case let .operation( operation ) = currentNode else { return [] }
                    let newWeight = operation( current.weight, value )
                    if newWeight > 0 {
                        queue.append( QueueEntry( nextPosition, current.path + [ direction ], newWeight ) )
                    }
                case .target( let value ):
                    guard case let .operation( operation ) = currentNode else { return [] }
                    let newWeight = operation( current.weight, value )
                    if newWeight == targetWeight { return current.path + [ direction ] }
                }
            }
        }
        
        return []
    }
}
