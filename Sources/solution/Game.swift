//
//  Game.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/28/21.
//

import Foundation

struct Game {
    var computer:    SynacorCode
    var runQuiet:    Bool
    var inputQueue:  [String]
    var trace:       Bool
    var traceBuffer: [String]
    
    var isHalted:    Bool { computer.halted }
    
    init( memory: [UInt16] ) {
        computer    = SynacorCode( memory: memory )
        runQuiet    = false
        inputQueue  = []
        trace       = false
        traceBuffer = []
    }
    
    init( from other: Game ) {
        computer    = SynacorCode( from: other.computer )
        runQuiet    = other.runQuiet
        inputQueue  = other.inputQueue
        trace       = other.trace
        traceBuffer = other.traceBuffer
    }

    func command( value: String ) -> Void {
        computer.inputs.append( value + "\n" )
    }
    
    mutating func runUntilInput() throws -> String {
        var outputQueue = ""
        
        while true {
            if computer.nextInstruction.opcode == .in {
                if computer.inputs.isEmpty {
                    return outputQueue
                }
            }

            if trace { try traceBuffer.append( computer.trace() ) }
            if let output = try computer.step(), output.isASCII {
                outputQueue.append( output )
            }
            
            if isHalted { break }
        }
        
        return outputQueue
    }
    
    mutating func send( command: String ) throws -> String {
        if !runQuiet { print( command ) }
        self.command( value: command )
        
        let output = try runUntilInput()
        if !runQuiet { print( output, terminator: "" ) }
        return output
    }
    
    mutating func interactive() throws -> String {
        while true {
            let output = try runUntilInput()

            print( output, terminator: "" )
            if isHalted { return output }

            if computer.inputs.isEmpty {
                if inputQueue.isEmpty {
                    let line = readLine( strippingNewline: true ) ?? ""
                    
                    command( value: line )
                } else {
                    let line = inputQueue.removeFirst()
                    
                    command( value: line )
                    print( line )
                }
            }
        }
    }
}
