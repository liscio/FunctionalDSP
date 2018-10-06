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

    init(inputCount: Int, outputCount: Int, process: @escaping ([SignalType]) -> [SignalType])

    associatedtype SignalType
    var inputCount: Int { get }
    var outputCount: Int { get }
    var process: ([SignalType]) -> [SignalType] { get }
    
}

public struct Block: BlockType {

    public init(inputCount: Int, outputCount: Int, process: @escaping ([Signal]) -> [Signal]) {
        self.inputCount = inputCount
        self.outputCount = outputCount
        self.process = process
    }

    public typealias SignalType = Signal

    public var inputCount: Int
    public var outputCount: Int
    public var process: ([Signal]) -> [Signal]

}

public func identity(_ inputs: Int) -> Block {
    return Block(inputCount: inputs, outputCount: inputs, process: { $0 })
}

//
//   -block-----
//  =|=[A]=[B]=|=
//   -----------
//

/// Runs two blocks serially
public func serial<B: BlockType>(_ lhs: B, rhs: B) -> B {
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
public func parallel<B: BlockType>(_ lhs: B, rhs: B) -> B {
    let totalInputs = lhs.inputCount + rhs.inputCount
    let totalOutputs = lhs.outputCount + rhs.outputCount
    
    return B(inputCount: totalInputs, outputCount: totalOutputs, process: { inputs in
        var outputs: [B.SignalType] = []
        
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
public func merge<B: BlockType>(_ lhs: B, rhs: B) -> B where B.SignalType == Signal {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        let leftOutputs = lhs.process(inputs)
        var rightInputs: [B.SignalType] = []

        let k = lhs.outputCount / rhs.inputCount
        for i in 0..<rhs.inputCount  {
            var inputsToSum = Array<B.SignalType>()
            for j in 0..<k {
                inputsToSum.append(leftOutputs[i+(rhs.inputCount*j)])
            }
            let summed = inputsToSum.reduce(NullSignal) { mix($0, s2: $1) }
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
public func split<B: BlockType>(_ lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        let leftOutputs = lhs.process(inputs)
        var rightInputs: [B.SignalType] = []
        
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
    return parallel(lhs, rhs: rhs)
}

// Serial
public func --<B: BlockType>(lhs: B, rhs: B) -> B {
    return serial(lhs, rhs: rhs)
}

// Split
public func -<<B: BlockType>(lhs: B, rhs: B) -> B {
    return split(lhs, rhs: rhs)
}

// Merge
public func >-<B: BlockType>(lhs: B, rhs: B) -> B where B.SignalType == Signal {
    return merge(lhs, rhs: rhs)
}
