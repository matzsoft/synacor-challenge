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
    var breakpoints: Set<Int>

    var stackTrace:       Bool
    var stackTraceBuffer: [SynacorCode.StackTraceInfo]
    var stackTraceLimit:  Int
    var stackTraceStack:  [Int]
    
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
        breakpoints = Set()

        stackTrace       = false
        stackTraceBuffer = []
        stackTraceLimit  = Int.max
        stackTraceStack  = []

    }
    
    init( from other: Game ) {
        fileURL     = other.fileURL
        computer    = SynacorCode( from: other.computer )
        runQuiet    = other.runQuiet
        inputQueue  = other.inputQueue
        trace       = other.trace
        traceBuffer = other.traceBuffer
        breakpoints = other.breakpoints

        stackTrace       = other.stackTrace
        stackTraceBuffer = other.stackTraceBuffer
        stackTraceLimit  = other.stackTraceLimit
        stackTraceStack  = other.stackTraceStack
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

            if breakpoints.contains( computer.ip ) {
                print( "Breakpoint at \( try computer.disassemble( address: computer.ip ) )" )
                try debugMode()
            }
            if trace { try traceBuffer.append( computer.trace() ) }
            if stackTrace {
                if var row = try computer.stackTrace() {
                    if row.pushedValue != nil { stackTraceStack.append( stackTraceBuffer.count ) }
                    if row.poppedValue != nil {
                        let cross = stackTraceStack.removeLast()
                        row.crossRow = cross
                        stackTraceBuffer[cross].crossRow = stackTraceBuffer.count
                    }
                    stackTraceBuffer.append( row )
                }
                
                if stackTraceBuffer.count >= stackTraceLimit {
                    stackTrace = false
                    print( "Stack trace full at \( try computer.disassemble( address: computer.ip ) )" )
                    try debugMode()
                }
            }
            if let output = try computer.step(), output.isASCII {
                outputQueue.append( output )
            }
            
            if isHalted { break }
        }
        
        return outputQueue
    }
    
    @discardableResult mutating func send( command: String ) throws -> String {
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
        case "help":
            if words.count > 1 {
                helpCommand( argument: words[1] )
                print( prompt )
            } else {
                print( "The metacommands are save, restore, restart, debug, solve, and die. ",
                       "For more information type \"help <command>\"." )
                command( value: "help" )
            }
        case "save":
            let encoder = JSONEncoder()
            let json = try encoder.encode( computer )
            let file = words.count < 2 ? "challenge.json" : "\(words[1]).json"
            
            try json.write( to: URL( fileURLWithPath: file ) )
            print( prompt )
        case "restore":
            let decoder = JSONDecoder()
            let file = words.count < 2 ? "challenge.json" : "\(words[1]).json"
            let json = try Data( contentsOf: URL( fileURLWithPath: file ) )
            
            computer = try decoder.decode( SynacorCode.self, from: json )
            command( value: "look" )
        case "restart":
            computer = try Game.initialComputer( from: fileURL )
        case "debug":
            try debugMode()
            print( prompt )
        case "solve":
            guard words.count > 1 else {
                print( "Solve what?" )
                print( prompt )
                break
            }
            switch words[1] {
            case "teleporter":
                solveTeleporter( prompt: prompt )
            case "vault":
                try solveVault()
            default:
                print( "Don't know how to solve \(words[1])." )
                print( prompt )
            }
        case "die":
            print( "You do your best grue mating call and are soon eaten by a pack of angry grues." )
            computer.halted = true
        default:
            command( value: line )
        }
    }
    
    func helpCommand<T: StringProtocol>( argument: T ) -> Void {
        switch argument {
        case "save":
            print( "Saves the current game state to a .json file. With no argument, the file will be",
                   "challenge.json.  If an argument is given it will be used as the name of the file.\n" )
        case "restore":
            print( "Restores the game state from a previously saved .json file. With no argument, the",
                   "file will be challenge.json.  If an argument is given it will be used as the name of",
                   "the file.\n" )
        case "restart":
            print( "Restarts your game from the beginning, all changes lost.\n" )
        case "debug":
            print( "Enter a debug mode where you can interact directly with the computer running the game.",
                   "Commands are:\n" )
            print( "b - set or list breakpoints. With no argument, all current breakpoints will be listed.",
                   "If an argument is given, it should be the address of where you wish to set a",
                   "breakpoint. When the computer is about to execute an instruction that has a",
                   "breakpoint set, it will instead enter debug mode.\n" )
            print( "B - clear or list breakpoints. With no argument, all current breakpoints will be",
                   "listed. If an argument is given, it should be the address of a breakpoint that",
                   "you wish to clear.\n" )
            print( "ip - display or change the instruction pointer.  With no argument, the current",
                   "value of the ip is displayed. To change the value give an acceptable number",
                   "as the argument.\n" )
            print( "r0, r1, ..., r7 - display or change the value of a register. Works like ip.\n" )
            print( "address - display or change the value of a memory location. Works like ip.\n" )
            print( "trace - work with trace mode. When trace mode is on, just before each instruction",
                   "is executed a line is placed in the trace buffer.  The line consists of the ip address,",
                   "the disassembled instruction, and an interpretation of the instruction's action.",
                   "The trace command takes one optional argument.  An argument of on or off turns trace",
                   "mode on or off respectively.  No argument toggles the mode.  An argument of clear will",
                   "empty the trace buffer. Any other argument is taken as the name of a file where",
                   "the trace buffer will be written. The file will be given the extension .trace.\n" )
            print( "disassemble - disassembles a portion of memory and writes the result to a file. The",
                   "command has two optional arguments.  The first argument is the address to start the",
                   "disassembly. It defaults to zero.  The second argument is the name of the file to",
                   "contain the results.  It defaults to \"challenge\" and a .asm extension is added.",
                   "The disassembly follows all execution paths that it can.\n" )
            print( "stack - works with stack trace mode.  This works like trace mode with some important",
                   "differences.  One big difference is that only instructions that affect the stack are",
                   "traced. Another is that \"stack on\" can take an addition argument, the stack trace",
                   "limit.  When set and the stack trace buffer reaches the limit, a breakpoint will be",
                   "simulated. Finally the output is quite different and hence is written to a .csv file.",
                   "There are 7 columns in the data - ip, opcode, pushed value, r0, r1, popped value, and",
                   "cross row.  The cross row is a one relative line number within the output that points",
                   "to the other side of the push or pop operation.\n" )
            print( "go - resumes execution of the program.  That is it exits debug mode.\n")
        case "solve":
            print( "Requires an argument which may be either teleporter or vault.\n" )
            print( "For teleporter, you must have the teleporter in your possession. The game will be",
                   "modified so that \"use teleporter\" will take you to the alternate destination.\n" )
            print( "For vault, you must be in the Vault Antechamber.  You will be moved to the Vault",
                   "Door with the vault unlocked.\n" )
        case "die":
            print( "Ends your game and exits the program.\n" )
        default:
            print( "No help available for \(argument).\n" )
        }
    }
    
    func solveTeleporter( prompt: String ) -> Void {
        let r0 = computer.memory[5485]
        let r1 = computer.memory[5488]
        let desired = computer.memory[5494]
        
        print( "Be patient.  This will take awhile, but not billions of years." )
        print( "This crude progress bar will NOT fill completely." )
        print( String( repeating: "=", count: 32 ) )
        
        for r7 in stride( from: ( desired.isMultiple( of: 2 ) ? 2 : 1 ), to: 32768, by: 2 ) {
            if r7 % 1000 < 2 { print( "*", terminator: "" ); fflush( __stdoutp ) }
            if synacor( m: Int( r0 ), n: Int( r1 ), mystery: r7 ) == desired {
                print( "" )
                print( "Setting r7 to \(r7)" )
                computer.registers[7] = UInt16( r7 )
                print( "Overiding call to confirmation routine." )
                computer.memory[5489] = SynacorCode.Opcode.noop.rawValue
                computer.memory[5490] = SynacorCode.Opcode.noop.rawValue
                computer.memory[5493] = desired
                break
            }
        }
        print( prompt )
    }
    
    mutating func solveVault() throws -> Void {
        let vault = Vault()
        
        try send( command: "take orb" )
        try vault.findShortestPath().forEach { try send( command: "\($0)" ) }
    }
    
    mutating func debugMode() throws -> Void {
        let prompt = "debug command?"
        
        LOOP:
        while true {
            print( prompt )

            let line = readLine() ?? ""
            let words = line.split( separator: " " )
            
            guard !words.isEmpty else { continue }
            switch words[0] {
            case "b":
                if words.count > 1 {
                    breakpoints.insert( Int( words[1] )! )
                } else {
                    print( "Breakpoints:" )
                    try breakpoints.map { try computer.disassemble( address: $0 ) }.forEach {
                        print("   \($0)" )
                    }
                }
            case "B":
                if words.count > 1 {
                    breakpoints.remove( Int( words[1] )! )
                } else {
                    print( "Breakpoints:", breakpoints.map { String( $0 ) }.joined( separator: ", " ) )
                }
            case "ip":
                if words.count > 1 {
                    computer.ip = Int( words[1] )!
                }
                print( "ip:", computer.ip )
            case "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7":
                let register = Int( words[0].dropFirst() )!
                if words.count > 1 {
                    computer.registers[register] = UInt16( words[1] )!
                }
                print( words[0], "=", computer.registers[register] )
            case let address where Int( address ) != nil:
                let address = Int( address )!
                if words.count > 1 {
                    computer.memory[address] = UInt16( words[1] )!
                }
                print( "Memory at", address, "contains", computer.memory[address] )
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
            case "disassemble":
                let start = words.count < 2 ? 0 : Int( words[1] )!
                let file = words.count < 3 ? "challenge.asm" : "\(words[2]).asm"
                let results = try computer.disassembler( address: start ).joined( separator: "\n" )
                
                try results.write( toFile: file, atomically: true, encoding: .utf8 )
            case "stack":
                if words.count == 1 {
                    stackTrace = !stackTrace
                } else {
                    switch words[1] {
                    case "on":
                        stackTrace = true
                        if words.count > 2 {
                            stackTraceLimit = Int( words[2] )!
                        }
                    case "off":
                        stackTrace = false
                    case "clear":
                        stackTraceBuffer = []
                    default:
                        let buffer = stackTraceBuffer.map { "\($0)" }.joined( separator: "\n" )
                        try buffer.write( toFile: "\(words[1]).csv", atomically: true, encoding: .utf8 )
                    }
                }
                print( "Stack trace mode is now \( stackTrace ? "on" : "off" )." )
            case "go":
                break LOOP
            default:
                break
            }
        }
    }
}

func synacor( m: Int, n: Int, mystery: Int ) -> Int {
    enum Place { case entry, first, store }
    var cache = Array( repeating: Array<Int?>( repeating: nil, count: 32768 ), count: 5 )
    var stack = [ ( m, n, Place.entry ) ]
    var value = 0
    
    while !stack.isEmpty {
        let ( m, n, place ) = stack.removeLast()
        
        switch place {
        case .entry:
            if m == 0 {
                value = ( n + 1 ) & 32767
            } else {
                if let cached = cache[m][n] {
                    value = cached
                } else {
                    stack.append( ( m, n, .store ) )
                    if n == 0 {
                        stack.append( ( m - 1, mystery, .entry ) )
                    } else {
                        stack.append( ( m - 1, value, .first ) )
                        stack.append( ( m, n - 1, .entry ) )
                    }
                }
            }
        case .first:
            stack.append( ( m, value, .entry ) )
        case .store:
            cache[m][n] = value
        }
    }
    
    return value
}
