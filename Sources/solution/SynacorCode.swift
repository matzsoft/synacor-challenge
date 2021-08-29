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

    func operandDescription( operandNumber: Int ) throws -> String {
        let operand = memory[ ip + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            return "r" + String( operand - 32768 )
        } else {
            return String( operand )
        }
    }

    func storeLocation( operandNumber: Int ) throws -> String {
        let operand = memory[ ip + operandNumber ]
        
        if operand > 32775 {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) is to large at ip \(ip)" )
        } else if operand > 32767 {
            return "r" + String( operand - 32768 )
        } else {
            throw RuntimeError( "Operand \(operandNumber) (\(operand)) not a register at ip \(ip)" )
        }
    }

    func trace() throws -> String {
        var line = String( format: "%04d: ", ip )

        func pad() -> Void {
            let column = 35
            guard line.count < column else { return }
            line.append( String( repeating: " ", count: column - line.count ) )
        }

        switch nextInstruction {
        case .halt:
            line.append( "halt" )
        case .set:
            let oldValue = try fetch( operandNumber: 1 )
            let newValue = try fetch( operandNumber: 2 )

            line.append( "set " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(newValue) replacing \(oldValue)" )
        case .push:
            let newValue = try fetch( operandNumber: 1 )

            line.append( "push " )
            line.append( "\( try operandDescription( operandNumber: 1 ) )" )
            pad()
            line.append( "push \(newValue)" )
        case .pop:
            let oldValue = try fetch( operandNumber: 1 )
            let newValue = stack.isEmpty ? "** Error **" : String( stack.last! )

            line.append( "pop " )
            line.append( "\( try storeLocation( operandNumber: 1 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(newValue) replacing \(oldValue)" )
        case .eq:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left == right ? 1 : 0

            line.append( "eq " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) == \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .gt:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left > right ? 1 : 0

            line.append( "gt " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) > \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .jmp:
            let destination = try fetch( operandNumber: 1 )

            line.append( "jmp " )
            line.append( "\( try operandDescription( operandNumber: 1 ) )" )
            pad()
            line.append( "ip = \(destination)" )
        case .jt:
            let boolean = try fetch( operandNumber: 1 )
            let destination = try fetch( operandNumber: 2 )

            line.append( "jt " )
            line.append( "\( try operandDescription( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) )" )
            pad()
            line.append( "if \(boolean) then ip = \(destination) " )
            line.append( boolean != 0 ? "(jmp)" : "(noop)" )
        case .jf:
            let boolean = try fetch( operandNumber: 1 )
            let destination = try fetch( operandNumber: 2 )

            line.append( "jf " )
            line.append( "\( try operandDescription( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) )" )
            pad()
            line.append( "if not \(boolean) then ip = \(destination) " )
            line.append( boolean == 0 ? "(jmp)" : "(noop)" )
        case .add:
            let oldValue = try fetch( operandNumber: 1 )
            let left = Int( try fetch( operandNumber: 2 ) )
            let right = Int( try fetch( operandNumber: 3 ) )
            let newValue = ( left + right ) & 32767

            line.append( "add " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) + \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .mult:
            let oldValue = try fetch( operandNumber: 1 )
            let left = Int( try fetch( operandNumber: 2 ) )
            let right = Int( try fetch( operandNumber: 3 ) )
            let newValue = ( left * right ) & 32767

            line.append( "mult " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) * \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .mod:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left % right

            line.append( "mod " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) % \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .and:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left & right

            line.append( "and " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) & \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .or:
            let oldValue = try fetch( operandNumber: 1 )
            let left = try fetch( operandNumber: 2 )
            let right = try fetch( operandNumber: 3 )
            let newValue = left | right

            line.append( "or " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 3 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(left) | \(right) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .not:
            let oldValue = try fetch( operandNumber: 1 )
            let value = try fetch( operandNumber: 2 )
            let newValue = ~value & 32767

            line.append( "not " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = ~\(value) " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .rmem:
            let oldValue = try fetch( operandNumber: 1 )
            let address = try Int( fetch( operandNumber: 2 ) )
            let newValue = memory[address]

            line.append( "rmem " )
            line.append( "\( try storeLocation( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) )" )
            pad()
            line.append( "\( try storeLocation( operandNumber: 1 ) ) = memory[\(address)] " )
            line.append( "replacing \(oldValue) with \(newValue)" )
        case .wmem:
            let address = try Int( fetch( operandNumber: 1 ) )
            let oldValue = memory[address]
            let newValue = try Int( fetch( operandNumber: 2 ) )

            line.append( "wmem " )
            line.append( "\( try operandDescription( operandNumber: 1 ) ), " )
            line.append( "\( try operandDescription( operandNumber: 2 ) )" )
            pad()
            line.append( "memory[\(address)] = \(newValue) replacing \(oldValue)" )
        case .call:
            let destination = try fetch( operandNumber: 1 )

            line.append( "call " )
            line.append( "\( try operandDescription( operandNumber: 1 ) )" )
            pad()
            line.append( "push \(ip+2); ip = \(destination)" )
        case .ret:
            line.append( "ret" )
            pad()
            line.append( stack.isEmpty ? "halt" : "ip = \(stack.last!)" )
        case .out:
            let code = try fetch( operandNumber: 1 )
            let output = Character( UnicodeScalar( code )! )

            line.append( "out " )
            line.append( "\( try operandDescription( operandNumber: 1 ) )" )
            pad()
            line.append( "output \(code) or ASCII \"\(output)\"" )
        case .in:
            line.append( "pop " )
            line.append( "\( try storeLocation( operandNumber: 1 ) )" )
            pad()

            if inputs.isEmpty {
                line.append( "** Blocks waiting for input **" )
            } else {
                let oldValue = try fetch( operandNumber: 1 )
                let character = inputs.removeFirst()
                let newValue = UInt16( character.asciiValue! )
                
                line.append( "\( try storeLocation( operandNumber: 1 ) ) = \(newValue) " )
                line.append( "or ASCII \"\(character)\" replacing \(oldValue)" )
            }
        case .noop:
            line.append( "noop" )
        }

        return line
    }
}
