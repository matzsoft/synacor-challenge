//
//  main.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/26/21.
//

import  Foundation

let size = MemoryLayout<UInt16>.stride
let rawData = try Data( contentsOf: URL( fileURLWithPath: "challenge.bin" ) )
let initialMemory = rawData.withUnsafeBytes { ( bufferPointer: UnsafeRawBufferPointer ) -> [UInt16] in
    guard let baseAddress = bufferPointer.baseAddress, bufferPointer.count > 0 else {
        return [UInt16]()
    }
    return stride( from: baseAddress, to: baseAddress + bufferPointer.count, by: size ).map {
        $0.load( as: UInt16.self )
    }
}

var computer = SynacorCode( memory: initialMemory )
var outBuffer = ""

while true {
    while !computer.halted {
        if let output = try computer.execute() {
            if output != "\n" {
                outBuffer.append( output )
            } else {
                print( outBuffer )
                outBuffer = ""
            }
        } else {
            let line = readLine( strippingNewline: false )!
            switch line {
            case "save\n":
                let encoder = JSONEncoder()
                let json = try encoder.encode( computer )
                
                try json.write( to: URL( fileURLWithPath: "challenge.json" ) )
                computer.inputs = "look\n"
            case "restore\n":
                let decoder = JSONDecoder()
                let json = try Data( contentsOf: URL( fileURLWithPath: "challenge.json" ) )
                
                computer = try decoder.decode( SynacorCode.self, from: json )
                computer.inputs = "look\n"
            default:
                computer.inputs = line
            }
        }
    }
    
    LOOP:
    while true {
        print( "Do you want to restore or restart?" )
        guard let command = readLine() else { break }
        switch command {
        case "restore":
            let decoder = JSONDecoder()
            let json = try Data( contentsOf: URL( fileURLWithPath: "challenge.json" ) )
            
            computer = try decoder.decode( SynacorCode.self, from: json )
            computer.inputs = "look\n"
            break LOOP
        case "restart":
            computer = SynacorCode( memory: initialMemory )
            break LOOP
        default:
            print( "Huh?" )
        }
    }
}
