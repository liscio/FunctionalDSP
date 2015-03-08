//
//  FunctionalDSP.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 3/8/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import AudioToolbox

// Just to demonstrate, mixing doubles and floats for parameter and sample types, respectively
typealias ParameterType = Double
typealias SampleType = Float

typealias SignalProcessor = (Int, SampleType) -> SampleType
typealias BlockSignalProcessor = ([Int], [SampleType]) -> [SampleType]

typealias Signal = (Int) -> SampleType

/// Convert any per-sample processor into a block processor
func toBlock(processor: SignalProcessor) -> BlockSignalProcessor {
    return { (indexes, samples) in
        var output = [SampleType](count: indexes.count, repeatedValue: 0)
        for (i, (index, sample)) in enumerate(zip(indexes, samples)) {
             output[i] = processor(index, sample)
        }
        return output
    }
}

/// Scale a signal by a given amplitude
func scale(s: Signal, amplitude: ParameterType) -> Signal {
    return { i in
        return SampleType(s(i) * SampleType(amplitude))
    }
}

/// Mix two signals together
func mix_2(s1: Signal, s2: Signal) -> Signal {
    return { i in
        return s1(i) + s2(i)
    }
}

/// Mix an arbitrary number of signals together
func mix_n(signals: [Signal]) -> Signal {
    return { i in
        return signals.reduce(SampleType(0)) { $0 + $1(i) }
    }
}

/// Generate a sine wave
func sineWave(sampleRate: Int, frequency: ParameterType) -> Signal {
    let phi = frequency / ParameterType(sampleRate)
    return { i in
        return SampleType(sin(2.0 * ParameterType(i) * phi * ParameterType(M_PI)))
    }
}

/// Read count samples from the signal starting at the specified index
func getOutput(signal: Signal, index: Int, count: Int) -> [SampleType] {
    return [Int](index..<count).map { signal($0) }
}

// MARK: -
// MARK: Reference implementation

let dtmfFrequencies = [
    ( 941.0, 1336.0 ),
    
    ( 697.0, 1209.0 ),
    ( 697.0, 1336.0 ),
    ( 697.0, 1477.0 ),
    
    ( 770.0, 1209.0 ),
    ( 770.0, 1336.0 ),
    ( 770.0, 1477.0 ),
    
    ( 852.0, 1209.0 ),
    ( 852.0, 1336.0 ),
    ( 852.0, 1477.0 ),
]

func dtmfTone(digit: Int, sampleRate: Int) -> Signal {
    assert( digit < dtmfFrequencies.count )
    let (f1, f2) = dtmfFrequencies[digit]
    return mix_2( sineWave(sampleRate, f1), sineWave(sampleRate, f2) )
}

let sampleRate = 44100

let phoneNumber = [8, 6, 7, 5, 3, 0, 9]
let signals = phoneNumber.map { dtmfTone($0, sampleRate) }

let toneDuration = sampleRate
let samples = signals.map { getOutput($0, 0, toneDuration) }.reduce([], combine: +)

