//
//  FunctionalDSP.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 3/8/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import CoreAudio
import AudioToolbox

// Just to demonstrate, mixing doubles and floats for parameter and sample types, respectively
public typealias ParameterType = Double
public typealias SampleType = Float

public typealias SignalProcessor = (Int, SampleType) -> SampleType
public typealias BlockSignalProcessor = ([Int], [SampleType]) -> [SampleType]

public typealias Signal = (Int) -> SampleType

/// Convert any per-sample processor into a block processor
public func toBlock(processor: SignalProcessor) -> BlockSignalProcessor {
    return { (indexes, samples) in
        var output = [SampleType](count: indexes.count, repeatedValue: 0)
        for (i, (index, sample)) in enumerate(zip(indexes, samples)) {
             output[i] = processor(index, sample)
        }
        return output
    }
}

/// Scale a signal by a given amplitude
public func scale(s: Signal, amplitude: ParameterType) -> Signal {
    return { i in
        return SampleType(s(i) * SampleType(amplitude))
    }
}

/// Mix two signals together
public func mix_2(s1: Signal, s2: Signal) -> Signal {
    return { i in
        return s1(i) + s2(i)
    }
}

/// Mix an arbitrary number of signals together
public func mix_n(signals: [Signal]) -> Signal {
    return { i in
        return signals.reduce(SampleType(0)) { $0 + $1(i) }
    }
}

/// Generate a sine wave
public func sineWave(sampleRate: Int, frequency: ParameterType) -> Signal {
    let phi = frequency / ParameterType(sampleRate)
    return { i in
        return SampleType(sin(2.0 * ParameterType(i) * phi * ParameterType(M_PI)))
    }
}

/// Read count samples from the signal starting at the specified index
public func getOutput(signal: Signal, index: Int, count: Int) -> [SampleType] {
    return [Int](index..<count).map { signal($0) }
}

// MARK: -
// MARK: Reference implementation

