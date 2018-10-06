//
//  FunctionalDSPTests.swift
//  FunctionalDSPTests
//
//  Created by Christopher Liscio on 3/8/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Cocoa
import XCTest
import FunctionalDSP

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

func dtmfTone(_ digit: Int, sampleRate: Int) -> Block {
    assert( digit < dtmfFrequencies.count )
    let (f1, f2) = dtmfFrequencies[digit]
    
    let f1Block = Block(inputCount: 0, outputCount: 1, process: { _ in [sineWave(sampleRate, frequency: f1)] })
    let f2Block = Block(inputCount: 0, outputCount: 1, process: { _ in [sineWave(sampleRate, frequency: f2)] })
    
    return ( f1Block |- f2Block ) >- Block(inputCount: 1, outputCount: 1, process: { return $0 })
}

class FunctionalDSPTests: XCTestCase {
    func testDTMF() {
        let sampleRate = 44100
        
        let phoneNumber = [8, 6, 7, 5, 3, 0, 9]
        let signals = phoneNumber.map { dtmfTone($0, sampleRate: sampleRate) }
        
        let toneDuration = Int(Float(sampleRate) * 0.2)

        // The below concatenates all the signal samples together in a continuous tone
        // let samples = signals.map { getOutput($0, 0, toneDuration) }.reduce([], combine: +)
        
        let silence = [SampleType](repeating: 0, count: toneDuration)

        if let af = AudioFile(forWritingToURL: URL(fileURLWithPath: "/Users/chris/testfile.wav"),withBitDepth: 16, sampleRate: 44100, channelCount: 1) {
            
            for signal in signals {
                af.writeSamples(getOutput(signal.process([])[0], index: 0, count: toneDuration))
                af.writeSamples(silence)
            }
            
            af.close()
            XCTAssertTrue(true, "yay")
        } else {
            XCTAssertTrue(false, "oops")
        }
    }
    
    func testWhite() {
        let sampleRate = 44100
        
        let whiteBlock = Block(inputCount: 0, outputCount: 1, process: { _ in [whiteNoise()] })
        let filterBlock = Block(inputCount: 0, outputCount: 1, process: { inputs in inputs.map { pinkFilter($0) } } )
        
        let pinkNoise = whiteBlock -- filterBlock
        
        if let af = AudioFile(forWritingToURL: URL(fileURLWithPath: "/Users/chris/testwhite.wav"),withBitDepth: 16, sampleRate: 44100, channelCount: 1) {
            af.writeSamples(getOutput(whiteBlock.process([])[0], index: 0, count: 88200))
            af.close()
            XCTAssertTrue(true, "yay")
        } else {
            XCTAssertTrue(false, "oops")
        }
        
        if let af = AudioFile(forWritingToURL: URL(fileURLWithPath: "/Users/chris/testpink.wav"),withBitDepth: 16, sampleRate: 44100, channelCount: 1) {
            af.writeSamples(getOutput(pinkNoise.process([])[0], index: 0, count: 88200))
            af.close()
            XCTAssertTrue(true, "yay")
        } else {
            XCTAssertTrue(false, "oops")
        }
    }
    
}
