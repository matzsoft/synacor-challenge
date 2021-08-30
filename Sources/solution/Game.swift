//
//  Game.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/28/21.
//

import Foundation

struct Game {
    let fileURL:     URL
    var computer:    SynacorCode
    var runQuiet:    Bool
    var inputQueue:  [String]
    var trace:       Bool
    var traceBuffer: [String]
    
    var isHalted:    Bool { computer.halted }
    
    static func initialComputer( from url: URL ) throws -> SynacorCode {
        let size = MemoryLayout<UInt16>.stride
        let rawData = try Data( contentsOf: url )
        let initialMemory = rawData.withUnsafeBytes { ( bufferPointer: UnsafeRawBufferPointer ) -> [UInt16] in
            guard let baseAddress = bufferPointer.baseAddress, bufferPointer.count > 0 else {
                return [UInt16]()
            }
            return stride( from: baseAddress, to: baseAddress + bufferPointer.count, by: size ).map {
                $0.load( as: UInt16.self )
            }
        }

        return SynacorCode( memory: initialMemory )
    }
    
    init( from url: URL ) throws {
        fileURL     = url
        computer    = try Game.initialComputer( from: url )
        runQuiet    = false
        inputQueue  = []
        trace       = false
        traceBuffer = []
    }
    
    init( from other: Game ) {
        fileURL     = other.fileURL
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
            if computer.nextInstruction == .in {
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
                    try getCommand()
                } else {
                    let line = inputQueue.removeFirst()
                    
                    command( value: line )
                    print( line )
                }
            }
        }
    }
    
    mutating func getCommand() throws -> Void {
        let prompt = "What do you do?"
        let line = readLine() ?? ""
        let words = line.split( separator: " " )
        
        guard !words.isEmpty else {
            command( value: "help" )
            return
        }
        
        switch words[0] {
        case "save":
            let encoder = JSONEncoder()
            let json = try encoder.encode( computer )
            
            try json.write( to: URL( fileURLWithPath: "challenge.json" ) )
            print( prompt )
        case "restore":
            let decoder = JSONDecoder()
            let json = try Data( contentsOf: URL( fileURLWithPath: "challenge.json" ) )
            
            computer = try decoder.decode( SynacorCode.self, from: json )
            command( value: "look" )
        case "restart":
            computer = try Game.initialComputer( from: fileURL )
        case "trace":
            if words.count == 1 {
                trace = !trace
            } else {
                switch words[1] {
                case "on":
                    trace = true
                case "off":
                    trace = false
                case "clear":
                    traceBuffer = []
                default:
                    try traceBuffer.joined( separator: "\n" ).write(
                        toFile: "\(words[1]).trace", atomically: true, encoding: .utf8 )
                }
            }
            print( "Trace mode is now \( trace ? "on" : "off" )." )
            print( prompt )
        case "r7":
            if words.count > 1 {
                computer.registers[7] = UInt16( words[1] )!
            }
            print( "The eighth register is \( computer.registers[7] )." )
            print( prompt )
        case "die":
            print( "You do your best grue mating call and are soon eaten by a pack of angry grues." )
            computer.halted = true
        default:
            command( value: line )
        }
    }
}
