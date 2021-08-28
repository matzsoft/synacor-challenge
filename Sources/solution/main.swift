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
var savedComputer: SynacorCode?
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
                savedComputer = SynacorCode( from: computer )
                computer.inputs = "look\n".map { UInt16( $0.asciiValue! ) }
            case "restore\n":
                if let savedComputer = savedComputer {
                    computer = SynacorCode( from: savedComputer )
                } else {
                    print( "You have not saved yet!" )
                }
                computer.inputs = "look\n".map { UInt16( $0.asciiValue! ) }
            default:
                computer.inputs = line.map { UInt16( $0.asciiValue! ) }
            }
        }
    }
    
    guard let savedComputer = savedComputer else {
        print( "Computer halted.  You must have died... Restarting!" )
        computer = SynacorCode( memory: initialMemory )
        continue
    }
    
    LOOP:
    while true {
        print( "Do you want to restore or restart?" )
        guard let command = readLine() else { break }
        switch command {
        case "restore":
            computer = SynacorCode( from: savedComputer )
            computer.inputs = "look\n".map { UInt16( $0.asciiValue! ) }
            break LOOP
        case "restart":
            computer = SynacorCode( memory: initialMemory )
            break LOOP
        default:
            print( "Huh?" )
        }
    }
}
