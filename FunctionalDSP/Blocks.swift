//
//  Blocks.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 4/14/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation

// Inspired by Faust:
// http://faust.grame.fr/index.php/documentation/references/12-documentation/reference/48-faust-syntax-reference-art

/// A block has zero or more inputs, and produces zero or more outputs
public protocol BlockType {
    typealias SignalType
    var inputCount: Int { get }
    var outputCount: Int { get }
    var process: [SignalType] -> [SignalType] { get }
    
    init(inputCount: Int, outputCount: Int, process: [SignalType] -> [SignalType])
}

public struct Block: BlockType {
    typealias SignalType = Signal
    
    public let inputCount: Int
    public let outputCount: Int
    public let process: [Signal] -> [Signal]
    
    public init(inputCount: Int, outputCount: Int, process: [Signal] -> [Signal]) {
        self.inputCount = inputCount
        self.outputCount = outputCount
        self.process = process
    }
}

public func identity(inputs: Int) -> Block {
    return Block(inputCount: inputs, outputCount: inputs, process: { $0 })
}

//
//   -block-----
//  =|=[A]=[B]=|=
//   -----------
//

/// Runs two blocks serially
public func serial<B: BlockType>(lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        return rhs.process(lhs.process(inputs))
    })
}

//
//   -block---
//  =|==[A]==|=
//  =|==[B]==|=
//   ---------
//

/// Runs two blocks in parallel
public func parallel<B: BlockType>(lhs: B, rhs: B) -> B {
    let totalInputs = lhs.inputCount + rhs.inputCount
    let totalOutputs = lhs.outputCount + rhs.outputCount
    
    return B(inputCount: totalInputs, outputCount: totalOutputs, process: { inputs in
        var outputs = Array<B.SignalType>()
        
        outputs += lhs.process(Array<B.SignalType>(inputs[0..<lhs.inputCount]))
        outputs += rhs.process(Array<B.SignalType>(inputs[lhs.inputCount..<lhs.inputCount+rhs.inputCount]))
        
        return outputs
    })
}

//
//   -block-------
//  =|=[A]=>-[B]-|-
//   -------------
//

/// Merges the outputs of the block on the left to the inputs of the block on the right
public func merge<B: BlockType where B.SignalType == Signal>(lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        let leftOutputs = lhs.process(inputs)
        var rightInputs = Array<B.SignalType>()

        let k = lhs.outputCount / rhs.inputCount
        for i in 0..<rhs.inputCount  {
            var inputsToSum = Array<B.SignalType>()
            for j in 0..<k {
                inputsToSum.append(leftOutputs[i+(rhs.inputCount*j)])
            }
            let summed = inputsToSum.reduce(NullSignal) { mix($0, $1) }
            rightInputs.append(summed)
        }

        return rhs.process(rightInputs)
    })
}

//
//     -block-------
//    -|-[A]-<=[B]=|=
//     -------------
//
//

/// Split the block on the left, replicating its outputs as necessary to fill the inputs of the block on the right
public func split<B: BlockType>(lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        let leftOutputs = lhs.process(inputs)
        var rightInputs = Array<B.SignalType>()
        
        // Replicate the channels from the lhs to each of the inputs
        let k = lhs.outputCount
        for i in 0..<rhs.inputCount {
            rightInputs.append(leftOutputs[i%k])
        }
        
        return rhs.process(rightInputs)
    })
}

// MARK: Operators

infix operator |- { associativity left }
infix operator -- { associativity left }
infix operator -< { associativity left }
infix operator >- { associativity left }

// Parallel
public func |-<B: BlockType>(lhs: B, rhs: B) -> B {
    return parallel(lhs, rhs)
}

// Serial
public func --<B: BlockType>(lhs: B, rhs: B) -> B {
    return serial(lhs, rhs)
}

// Split
public func -<<B: BlockType>(lhs: B, rhs: B) -> B {
    return split(lhs, rhs)
}

// Merge
public func >-<B: BlockType where B.SignalType == Signal>(lhs: B, rhs: B) -> B {
    return merge(lhs, rhs)
}