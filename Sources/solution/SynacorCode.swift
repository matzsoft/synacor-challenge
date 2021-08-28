//
//  SynacorCode.swift
//  Synacor Challenge
//
//  Created by Mark Johnson on 8/26/21.
//

import Foundation

class SynacorCode: Codable {
    struct Instruction {
        enum Opcode: UInt16 {
            case halt = 0, set = 1, push = 2, pop = 3, eq = 4, gt = 5, jmp = 6, jt = 7
            case jf = 8, add = 9, mult = 10, mod = 11, and = 12, or = 13, not = 14
            case rmem = 15, wmem = 16, call = 17, ret = 18, out = 19, `in` = 20, noop = 21
        }
        
        let opcode: Opcode

        init( instruction: UInt16 ) {
            opcode = Opcode( rawValue: instruction % 100 )!
        }
    }

    var ip:        Int
    var registers: [UInt16]
    var stack:     [UInt16]
    var memory:    [UInt16]
    var inputs:    [UInt16]
    var halted:    Bool
    var debug:     Bool
    
    var nextInstruction: Instruction {
        return Instruction( instruction: memory[ip] )
    }

    init( memory: [UInt16] ) {
        self.ip        = 0
        self.registers = Array( repeating: UInt16( 0 ), count: 8 )
        self.stack     = []
        self.memory    = memory
        self.inputs    = []
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
        let instruction = Instruction( instruction: memory[ip] )
        
        switch instruction.opcode {
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
            let output = try fetch( operandNumber: 1 )
            ip += 2
            return Character( UnicodeScalar( output )! )
        case .in:
            if inputs.isEmpty { return nil }
            try store( operandNumber: 1, value: inputs.removeFirst() )
            ip += 2
        case .noop:
            ip += 1
        }

        return nil
    }
    
    func execute() throws -> Character? {
        while !halted {
            if let output = try step() { return output }
            if nextInstruction.opcode == .in && inputs.isEmpty {
                return nil
            }
        }
        return nil
    }

//    func operandDescription( _ instruction: Instruction, operand: Int ) -> String {
//        let location = memory[ ip + operand ]
//        
//        switch instruction.mode( operand: operand ) {
//        case .position:
//            return "@\(location)"
//        case .immediate:
//            return "\(location)"
//        case .relative:
//            return "*\(location)"
//        }
//    }
//    
//    func storeLocation( _ instruction: Instruction, operand: Int ) throws -> Int {
//        var location = memory[ ip + operand ]
//        
//        switch instruction.mode( operand: operand ) {
//        case .position:
//            break
//        case .immediate:
//            throw RuntimeError( "Immediate mode invalid for address \(ip)" )
//        case .relative:
//            location += relativeBase
//        }
//
//        if location < 0 {
//            throw RuntimeError( "Negative memory store (\(location)) at address \(ip)" )
//        }
//        
//        return location
//    }
//
//    func trace() throws -> String {
//        let instruction = Instruction( instruction: memory[ip] )
//        var line = String( format: "%04d: ", ip )
//        
//        func pad() -> Void {
//            let column = 35
//            guard line.count < column else { return }
//            line.append( String( repeating: " ", count: column - line.count ) )
//        }
//        
//        switch instruction.opcode {
//        case .add:
//            let operand1 = try fetch( instruction, operand: 1 )
//            let operand2 = try fetch( instruction, operand: 2 )
//            
//            line.append( "add " )
//            line.append( "\(operandDescription( instruction, operand: 1 ) ), " )
//            line.append( "\(operandDescription( instruction, operand: 2 ) ), " )
//            line.append( operandDescription( instruction, operand: 3 ) )
//            pad()
//            line.append( "\(operand1) + \(operand2) = \(operand1 + operand2) -> " )
//            line.append( "\( try storeLocation( instruction, operand: 3 ) )" )
//        case .multiply:
//            let operand1 = try fetch( instruction, operand: 1 )
//            let operand2 = try fetch( instruction, operand: 2 )
//            
//            line.append( "multiply " )
//            line.append( "\(operandDescription( instruction, operand: 1 ) ), " )
//            line.append( "\(operandDescription( instruction, operand: 2 ) ), " )
//            line.append( operandDescription( instruction, operand: 3 ) )
//            pad()
//            line.append( "\(operand1) * \(operand2) = \(operand1 * operand2) -> " )
//            line.append( "\( try storeLocation( instruction, operand: 3 ) )" )
//        case .input:
//            let value = inputs.first!
//            line.append( "input " )
//            line.append( operandDescription( instruction, operand: 1 ) )
//            pad()
//            line.append( "input \(value)" )
//            if 0 < value && value < 256 {
//                if let code = UnicodeScalar( value ) {
//                    let char = Character( code )
//                    
//                    if char.isASCII {
//                        if char != "\n" {
//                            line.append( " \"\(char)\"" )
//                        } else {
//                            line.append( " \"\\n\"" )
//                        }
//                    }
//                }
//            }
//            line.append( " -> \( try storeLocation( instruction, operand: 1 ) )" )
//        case .output:
//            let operand1 = try fetch( instruction, operand: 1 )
//            
//            line.append( "output " )
//            line.append( operandDescription( instruction, operand: 1 ) )
//            pad()
//            line.append( "output \(operand1)" )
//            if 0 < operand1 && operand1 < 256 {
//                if let code = UnicodeScalar( operand1 ) {
//                    let char = Character( code )
//                    
//                    if char.isASCII {
//                        if char != "\n" {
//                            line.append( " \"\(char)\"" )
//                        } else {
//                            line.append( " \"\\n\"" )
//                        }
//                    }
//                }
//            }
//        case .jumpIfTrue:
//            let operand1 = try fetch( instruction, operand: 1 )
//            let operand2 = try fetch( instruction, operand: 2 )
//            
//            line.append( "jumpIfTrue " )
//            line.append( "\(operandDescription( instruction, operand: 1 ) ), " )
//            line.append( operandDescription( instruction, operand: 2 ) )
//            pad()
//            line.append( "jumpIfTrue \(operand1), \(operand2)" )
//        case .jumpIfFalse:
//            let operand1 = try fetch( instruction, operand: 1 )
//            let operand2 = try fetch( instruction, operand: 2 )
//            
//            line.append( "jumpIfFalse " )
//            line.append( "\(operandDescription( instruction, operand: 1 ) ), " )
//            line.append( operandDescription( instruction, operand: 2 ) )
//            pad()
//            line.append( "jumpIfFalse \(operand1), \(operand2)" )
//        case .lessThan:
//            let operand1 = try fetch( instruction, operand: 1 )
//            let operand2 = try fetch( instruction, operand: 2 )
//            
//            line.append( "lessThan " )
//            line.append( "\(operandDescription( instruction, operand: 1 ) ), " )
//            line.append( "\(operandDescription( instruction, operand: 2 ) ), " )
//            line.append( operandDescription( instruction, operand: 3 ) )
//            pad()
//            line.append( "\(operand1) < \(operand2) => \( operand1 < operand2 ? 1 : 0 ) -> " )
//            line.append( "\( try storeLocation( instruction, operand: 3 ) )" )
//        case .equals:
//            let operand1 = try fetch( instruction, operand: 1 )
//            let operand2 = try fetch( instruction, operand: 2 )
//            
//            line.append( "equals " )
//            line.append( "\(operandDescription( instruction, operand: 1 ) ), " )
//            line.append( "\(operandDescription( instruction, operand: 2 ) ), " )
//            line.append( operandDescription( instruction, operand: 3 ) )
//            pad()
//            line.append( "\(operand1) == \(operand2) => \( operand1 == operand2 ? 1 : 0 ) -> " )
//            line.append( "\( try storeLocation( instruction, operand: 3 ) )" )
//        case .relativeBaseOffset:
//            let operand1 = try fetch( instruction, operand: 1 )
//            
//            line.append( "relativeBaseOffset " )
//            line.append( operandDescription( instruction, operand: 1 ) )
//            pad()
//            line.append( "relativeBase = \( relativeBase + operand1 )" )
//        case .halt:
//            line.append( "halt" )
//        }
//
//        return line
//    }
}
