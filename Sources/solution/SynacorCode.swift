//
//  SynacorCode.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/26/21.
//

import Foundation

class SynacorCode: Codable {
    enum Opcode: UInt16 {
        case halt = 0, set = 1, push = 2, pop = 3, eq = 4, gt = 5, jmp = 6, jt = 7
        case jf = 8, add = 9, mult = 10, mod = 11, and = 12, or = 13, not = 14
        case rmem = 15, wmem = 16, call = 17, ret = 18, out = 19, `in` = 20, noop = 21
    }

    var ip:        Int
    var registers: [UInt16]
    var stack:     [UInt16]
    var memory:    [UInt16]
    var inputs:    String
    var halted:    Bool
    var debug:     Bool
    
    var nextInstruction: Opcode {
        return Opcode( rawValue: memory[ip] )!
    }

    init( memory: [UInt16] ) {
        self.ip        = 0
        self.registers = Array( repeating: UInt16( 0 ), count: 8 )
        self.stack     = []
        self.memory    = memory
        self.inputs    = ""
        halted         = false
        debug          = false
    }
    
    init( from other: SynacorCode ) {
        ip        = other.ip
        registers = other.registers
        stack     = other.stack
        memory    = other.memory
        inputs    = other.inputs
        halted    = other.halted
        debug     = other.debug
    }

    func fetch( operandNumber: Int ) throws -> UInt16 {
        let operand = memory[ ip + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            return registers[ Int( operand ) - 32768 ]
        } else {
            return operand
        }
    }
    
    func store( operandNumber: Int, value: UInt16 ) throws -> Void {
        let operand = memory[ ip + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            registers[ Int( operand ) - 32768 ] = value
        } else {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) not a register at ip \(ip)" )
        }
    }

    func step() throws -> Character? {
        guard !halted else { return nil }
        
        switch nextInstruction {
        case .halt:
            halted = true
        case .set:
            try store( operandNumber: 1, value: fetch( operandNumber: 2 ) )
            ip += 3
        case .push:
            stack.append( try fetch( operandNumber: 1 ) )
            ip += 2
        case .pop:
            if stack.isEmpty { throw RuntimeError( "Attempt to pop from empty stack at ip \(ip)." ) }
            try store( operandNumber: 1, value: stack.removeLast() )
            ip += 2
        case .eq:
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            try store( operandNumber: 1, value: left == right ? 1 : 0 )
            ip += 4
        case .gt:
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            try store( operandNumber: 1, value: left > right ? 1 : 0 )
            ip += 4
        case .jmp:
            ip = Int( try fetch( operandNumber: 1 ) )
        case .jt:
            let value = try fetch( operandNumber: 1 )
            ip = value != 0 ? Int( try fetch( operandNumber: 2 ) ): ip + 3
        case .jf:
            let value = try fetch( operandNumber: 1 )
            ip = value == 0 ? Int( try fetch( operandNumber: 2 ) ): ip + 3
        case .add:
            let left = Int( try fetch( operandNumber: 2 ) )
            let right = Int( try fetch( operandNumber: 3 ) )
            try store( operandNumber: 1, value: UInt16( ( left + right ) & 32767 ) )
            ip += 4
        case .mult:
            let left = Int( try fetch( operandNumber: 2 ) )
            let right = Int( try fetch( operandNumber: 3 ) )
            try store( operandNumber: 1, value: UInt16( ( left * right ) & 32767 ) )
            ip += 4
        case .mod:
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            try store( operandNumber: 1, value: left % right )
            ip += 4
        case .and:
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            try store( operandNumber: 1, value: left & right )
            ip += 4
        case .or:
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            try store( operandNumber: 1, value: left | right )
            ip += 4
        case .not:
            let value = try fetch( operandNumber: 2 )
            try store( operandNumber: 1, value: ~value & 32767 )
            ip += 3
        case .rmem:
            let address = try Int( fetch( operandNumber: 2 ) )
            try store( operandNumber: 1, value: memory[address] )
            ip += 3
        case .wmem:
            let address = try Int( fetch( operandNumber: 1 ) )
            memory[address] = try fetch( operandNumber: 2 )
            ip += 3
        case .call:
            stack.append( UInt16( ip ) + 2 )
            ip = try Int( fetch( operandNumber: 1 ) )
        case .ret:
            if !stack.isEmpty {
                ip = Int( stack.removeLast() )
            } else {
                halted = true
            }
        case .out:
            let output = Character( UnicodeScalar( try fetch( operandNumber: 1 ) )! )
            ip += 2
            return output
        case .in:
            if inputs.isEmpty { return nil }
            try store( operandNumber: 1, value: UInt16( inputs.removeFirst().asciiValue! ) )
            ip += 2
        case .noop:
            ip += 1
        }

        return nil
    }
    
    func execute() throws -> Character? {
        while !halted {
            if let output = try step() { return output }
            if nextInstruction == .in && inputs.isEmpty {
                return nil
            }
        }
        return nil
    }

    func operandDescription( address: Int, operandNumber: Int ) throws -> String {
        let operand = memory[ address + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            return "r" + String( operand - 32768 )
        } else {
            return String( operand )
        }
    }

    func storeLocation( address: Int, operandNumber: Int ) throws -> String {
        let operand = memory[ address + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            return "r" + String( operand - 32768 )
        } else {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) not a register at ip \(ip)" )
        }
    }

    func trace() throws -> String {
        var line = try disassemble( address: ip )

        func pad() -> Void {
            let column = 35
            guard line.count < column else { return }
            line.append( String( repeating: " ", count: column - line.count ) )
        }

        switch nextInstruction {
        case .halt:
            break
        case .set:
            let oldValue = try fetch( operandNumber: 1 )
            let newValue = try fetch( operandNumber: 2 )

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = " )
            line.append( "\(newValue) replacing \(oldValue)" )
        case .push:
            let newValue = try fetch( operandNumber: 1 )

            pad()
            line.append( "push \(newValue)" )
        case .pop:
            let oldValue = try fetch( operandNumber: 1 )
            let newValue = stack.isEmpty ? "** Error **" : String( stack.last! )

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = " )
            line.append( "\(newValue) replacing \(oldValue)" )
        case .eq:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left == right ? 1 : 0

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) == \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .gt:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left > right ? 1 : 0

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) > \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .jmp:
            let destination = try fetch( operandNumber: 1 )

            pad()
            line.append( "ip = \(destination)" )
        case .jt:
            let boolean = try fetch( operandNumber: 1 )
            let destination = try fetch( operandNumber: 2 )

            pad()
            line.append( "if \(boolean) then ip = \(destination) " )
            line.append( boolean != 0 ? "(jmp)" : "(noop)" )
        case .jf:
            let boolean = try fetch( operandNumber: 1 )
            let destination = try fetch( operandNumber: 2 )

            pad()
            line.append( "if not \(boolean) then ip = \(destination) " )
            line.append( boolean == 0 ? "(jmp)" : "(noop)" )
        case .add:
            let oldValue = try fetch( operandNumber: 1 )
            let left = Int( try fetch( operandNumber: 2 ) )
            let right = Int( try fetch( operandNumber: 3 ) )
            let newValue = ( left + right ) & 32767

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) + \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .mult:
            let oldValue = try fetch( operandNumber: 1 )
            let left = Int( try fetch( operandNumber: 2 ) )
            let right = Int( try fetch( operandNumber: 3 ) )
            let newValue = ( left * right ) & 32767

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) * \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .mod:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left % right

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) % \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .and:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left & right

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) & \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .or:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left | right

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(left) | \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .not:
            let oldValue = try fetch( operandNumber: 1 )
            let value = try fetch( operandNumber: 2 )
            let newValue = ~value & 32767

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = ~\(value) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .rmem:
            let oldValue = try fetch( operandNumber: 1 )
            let address = try Int( fetch( operandNumber: 2 ) )
            let newValue = memory[address]

            pad()
            line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = memory[\(address)] " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .wmem:
            let address = try Int( fetch( operandNumber: 1 ) )
            let oldValue = memory[address]
            let newValue = try Int( fetch( operandNumber: 2 ) )

            pad()
            line.append( "memory[\(address)] = \(newValue) replacing \(oldValue)" )
        case .call:
            let destination = try fetch( operandNumber: 1 )

            pad()
            line.append( "call \(ip+2); ip = \(destination)" )
        case .ret:
            pad()
            line.append( stack.isEmpty ? "halt" : "ip = \(stack.last!)" )
        case .out:
            let code = try fetch( operandNumber: 1 )
            let output = Character( UnicodeScalar( code )! )

            pad()
            line.append( "output \(code) or ASCII \"\(output)\"" )
        case .in:
            pad()

            if inputs.isEmpty {
                line.append( "** Blocks waiting for input **" )
            } else {
                let oldValue = try fetch( operandNumber: 1 )
                let character = inputs.first!
                let newValue = UInt16( character.asciiValue! )
                
                line.append( "\( try storeLocation( address: ip, operandNumber: 1 ) ) = \(newValue) " )
                line.append( "or ASCII \"\(character)\" replacing \(oldValue)" )
            }
        case .noop:
            break
        }

        return line
    }

    func disassemble( address: Int ) throws -> String {
        var line = String( format: "%04d: ", address )

        switch Opcode( rawValue: memory[address] ) {
        case .halt:
            line.append( "halt" )
        case .set:
            line.append( "set " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) )" )
        case .push:
            line.append( "push " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) )" )
        case .pop:
            line.append( "pop " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) )" )
        case .eq:
            line.append( "eq " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .gt:
            line.append( "gt " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .jmp:
            line.append( "jmp " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) )" )
        case .jt:
            line.append( "jt " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) )" )
        case .jf:
            line.append( "jf " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) )" )
        case .add:
            line.append( "add " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .mult:
            line.append( "mult " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .mod:
            line.append( "mod " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .and:
            line.append( "and " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .or:
            line.append( "or " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 3 ) )" )
        case .not:
            line.append( "not " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) )" )
        case .rmem:
            line.append( "rmem " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) )" )
        case .wmem:
            line.append( "wmem " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( address: address, operandNumber: 2 ) )" )
        case .call:
            line.append( "call " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) )" )
        case .ret:
            line.append( "ret" )
        case .out:
            line.append( "out " )
            line.append( "\( try operandDescription( address: address, operandNumber: 1 ) )" )
        case .in:
            line.append( "in " )
            line.append( "\( try storeLocation( address: address, operandNumber: 1 ) )" )
        case .noop:
            line.append( "noop" )
        case nil:
            throw RuntimeError( "Invalid opcode \(memory[address]) at address \(address)." )
        }

        return line
    }
    
    func immediateValue( address: Int, operandNumber: Int ) throws -> Int? {
        let operand = memory[ address + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            return nil
        } else {
            return Int( operand )
        }
    }

    func disassembler( address: Int ) throws -> [String] {
        var completed = [ Int : ( next: Int, description: String ) ]()
        var pending = Set( [ address ] )
        
        while !pending.isEmpty {
            var address = pending.removeFirst()
            
            while completed[address] == nil {
                let description = try disassemble( address: address )
                
                func add( nextOffset: Int, addressOffset: Int ) -> Void {
                    completed[address] = ( next: address + nextOffset, description: description )
                    address += addressOffset
                }
                
                switch Opcode( rawValue: memory[address] ) {
                case .halt:
                    add( nextOffset: 1, addressOffset: 0 )
                case .set:
                    add( nextOffset: 3, addressOffset: 3 )
                case .push:
                    add( nextOffset: 2, addressOffset: 2 )
                case .pop:
                    add( nextOffset: 2, addressOffset: 2 )
                case .eq:
                    add( nextOffset: 4, addressOffset: 4 )
                case .gt:
                    add( nextOffset: 4, addressOffset: 4 )
                case .jmp:
                    if let target = try immediateValue( address: address, operandNumber: 1 ) {
                        pending.insert( target )
                    }
                    add( nextOffset: 2, addressOffset: 0 )
                case .jt:
                    if let target = try immediateValue( address: address, operandNumber: 2 ) {
                        pending.insert( target )
                    }
                    add( nextOffset: 3, addressOffset: 3 )
                case .jf:
                    if let target = try immediateValue( address: address, operandNumber: 2 ) {
                        pending.insert( target )
                    }
                    add( nextOffset: 3, addressOffset: 3 )
                case .add:
                    add( nextOffset: 4, addressOffset: 4 )
                case .mult:
                    add( nextOffset: 4, addressOffset: 4 )
                case .mod:
                    add( nextOffset: 4, addressOffset: 4 )
                case .and:
                    add( nextOffset: 4, addressOffset: 4 )
                case .or:
                    add( nextOffset: 4, addressOffset: 4 )
                case .not:
                    add( nextOffset: 3, addressOffset: 3 )
                case .rmem:
                    add( nextOffset: 3, addressOffset: 3 )
                case .wmem:
                    add( nextOffset: 3, addressOffset: 3 )
                case .call:
                    if let target = try immediateValue( address: address, operandNumber: 1 ) {
                        pending.insert( target )
                    }
                    add( nextOffset: 2, addressOffset: 2 )
                case .ret:
                    add( nextOffset: 1, addressOffset: 0 )
                case .out:
                    add( nextOffset: 2, addressOffset: 2 )
                case .in:
                    add( nextOffset: 2, addressOffset: 2 )
                case .noop:
                    add( nextOffset: 1, addressOffset: 1 )
                case nil:
                    throw RuntimeError( "Invalid opcode \(memory[address]) at address \(address)." )
                }
            }
        }
        
        var results = completed.sorted( by: { $0.key < $1.key } )
        var index = 0
        
        while index < results.count - 1 {
            if results[index].value.next < results[ index + 1 ].key {
                results.insert( ( key: 0, value: ( next: 0, description: "..." ) ), at: index + 1 )
                index += 1
            }
            index += 1
        }
        return results.map { $0.value.description }
    }
    
    struct StackTraceInfo: CustomStringConvertible {
        let ip: Int
        let opcode: String
        let pushedValue: UInt16?
        let r0: UInt16
        let r1: UInt16
        let poppedValue: UInt16?
        var crossRow: Int?

        var description: String {
            return "\(ip),\(opcode),\( pushedValue  == nil ? "" : String( pushedValue! ) )," +
            "\(r0),\(r1),\( poppedValue  == nil ? "" : String( poppedValue! ) )," +
                ( crossRow  == nil ? "" : String( crossRow! + 1 ) )
        }
    }
    
    func stackTracePush( opcode: String, pushedValue: UInt16 ) -> StackTraceInfo {
        return StackTraceInfo(
            ip: ip, opcode: opcode, pushedValue: pushedValue,
            r0: registers[0], r1: registers[1], poppedValue: nil, crossRow: nil
        )
    }
    
    func stackTracePop( opcode: String, poppedValue: UInt16 ) -> StackTraceInfo {
        return StackTraceInfo(
            ip: ip, opcode: opcode, pushedValue: nil, r0: registers[0], r1: registers[1],
            poppedValue: poppedValue, crossRow: nil
        )
    }
    
    func stackTrace() throws -> StackTraceInfo? {
        switch nextInstruction {
        case .push:
            return try stackTracePush( opcode: "push", pushedValue: fetch( operandNumber: 1 ) )
        case .pop:
            if stack.isEmpty { throw RuntimeError( "Trying to pop with an empty stack." ) }
            return stackTracePop( opcode: "pop", poppedValue: stack.last! )
        case .call:
            return stackTracePush( opcode: "call", pushedValue: UInt16( ip + 2 ) )
        case .ret:
            if stack.isEmpty { throw RuntimeError( "Trying to ret with an empty stack." ) }
            return stackTracePop( opcode: "ret", poppedValue: stack.last! )
        default:
            return nil
        }
    }
}



// case halt:
// case set:
// case push:
// case pop:
// case eq:
// case gt:
// case jmp:
// case jt:
// case jf:
// case add:
// case mult:
// case mod:
// case and:
// case or:
// case not:
// case rmem:
// case wmem:
// case call:
// case ret:
// case out:
// case in:
// case noop:
