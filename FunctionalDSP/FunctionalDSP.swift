//
//  FunctionalDSP.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 3/8/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import Accelerate

// Just to demonstrate, mixing doubles and floats for parameter and sample types, respectively
public typealias ParameterType = Double
public typealias SampleType = Float

public typealias Signal = (Int) -> SampleType

public func NullSignal(_: Int) -> SampleType {
    return 0
}

// MARK: Basic Operations

/// Scale a signal by a given amplitude
public func signalscale(_ s: @escaping Signal, amplitude: ParameterType) -> Signal {
    return { i in
        return SampleType(s(i) * SampleType(amplitude))
    }
}

// MARK: Mixing

/// Mix two signals together
public func mix(_ s1: @escaping Signal, s2: @escaping Signal) -> Signal {
    return { i in
        return s1(i) + s2(i)
    }
}

/// Mix an arbitrary number of signals together
public func mix(_ signals: [Signal]) -> Signal {
    return { i in
        return signals.reduce(SampleType(0)) { $0 + $1(i) }
    }
}

// MARK: Generators

/// Generate a sine wave
public func sineWave(_ sampleRate: Int, frequency: ParameterType) -> Signal {
    let phi = frequency / ParameterType(sampleRate)
    return { i in
        return SampleType(sin(2.0 * ParameterType(i) * phi * ParameterType(Double.pi)))
    }
}

/// Simple white noise generator
public func whiteNoise() -> Signal {
    return { _ in
        return SampleType(-1.0 + 2.0 * (SampleType(arc4random_uniform(UInt32(Int16.max))) / SampleType(Int16.max)))
    }
}

// MARK: Output

/// Read count samples from the signal starting at the specified index
public func getOutput(_ signal: Signal, index: Int, count: Int) -> [SampleType] {
    return [Int](index..<count).map { signal($0) }
}

// MARK: Filtering

public typealias FilterType = Double
public extension FilterType {
    static let Epsilon = Double.ulpOfOne
}

public struct PinkFilter {
    // Filter coefficients from jos: https://ccrma.stanford.edu/~jos/sasp/Example_Synthesis_1_F_Noise.html
    var b: [FilterType] = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    var a: [FilterType] = [1.000000000, -2.494956002, 2.017265875, -0.522189400]
    
    // The filter's "memory"
    public var w: [FilterType]! = nil
    
    public init() {}
}

var gFilt = PinkFilter()
public func pinkFilter(_ x: @escaping Signal) -> Signal {
    return filt(x, b: gFilt.b, a: gFilt.a, w: &gFilt.w)
}

public func filt(_ x: @escaping Signal, b: [FilterType], a: [FilterType], w: inout [FilterType]!) -> Signal {
    var b = b, a = a
    let N = a.count
    let M = b.count
    let MN = max(N, M)
    let lw = MN - 1
    var w = w
    
    if w == nil {
        w = [FilterType](repeating: 0, count: lw)
    }
    assert(w?.count == lw)

    if b.count < MN {
        b = b + zeros(MN-b.count)
    }
    if a.count < MN {
        a = a + zeros(MN-a.count)
    }
    
    let norm = a[0]
    assert(norm > 0, "First element in A must be nonzero")
    if fabs(norm - 1.0) > FilterType.Epsilon {
        scale(&b, a: 1.0 / norm)
    }
    
    if N > 1 {
        // IIR Filter Case
        if fabs(norm - 1.0) > FilterType.Epsilon {
            scale(&a, a: 1.0 / norm)
        }

        return { i in
            let xi = FilterType(x(i))
            let y = (w?[0])! + (b[0] * xi)
            if ( lw > 1 ) {
                for j in 0..<(lw - 1) {
                    let bji = (b[j+1] * xi)
                    let aji = (a[j+1] * y)
                    w?[j] = (w?[j+1])! + bji - aji
                }
                w?[lw-1] = (b[MN-1] * xi) - (a[MN-1] * y)
            } else {
                w?[0] = (b[MN-1] * xi) - (a[MN-1] * y)
            }
            return SampleType(y)
        }
    } else {
        // FIR Filter Case
        if lw > 0 {
            return { i in
                let xi = FilterType(x(i))
                let y = (w?[0])! + b[0] * xi
                if ( lw > 1 ) {
                    for j in 0..<(lw - 1) {
                        w?[j] = (w?[j+1])! + (b[j+1] * xi)
                    }
                    w?[lw-1] = b[MN-1] * xi;
                }
                else {
                    w?[0] = b[1] * xi
                }
                return Float(y)
            }
        } else {
            // No delay
            return { i in Float(Double(x(i)) * b[0]) }
        }
    }
}


