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

func dtmfTone(digit: Int, sampleRate: Int) -> Signal {
    assert( digit < dtmfFrequencies.count )
    let (f1, f2) = dtmfFrequencies[digit]
    return mix( sineWave(sampleRate, f1), sineWave(sampleRate, f2) )
}

class FunctionalDSPTests: XCTestCase {
    func testDTMF() {
        let sampleRate = 44100
        
        let phoneNumber = [8, 6, 7, 5, 3, 0, 9]
        let signals = phoneNumber.map { dtmfTone($0, sampleRate) }
        
        let toneDuration = Int(Float(sampleRate) * 0.2)

        // The below concatenates all the signal samples together in a continuous tone
        // let samples = signals.map { getOutput($0, 0, toneDuration) }.reduce([], combine: +)
        
        let silence = [SampleType](count: toneDuration, repeatedValue: 0)

        if let af = AudioFile(forWritingToURL: NSURL(fileURLWithPath: "/Users/chris/testfile.wav")!, withBitDepth: 16, sampleRate: 44100, channelCount: 1) {
            
            for signal in signals {
                af.writeSamples(getOutput(signal, 0, toneDuration))
                af.writeSamples(silence)
            }
            
            af.close()
            XCTAssertTrue(true, "yay")
        } else {
            XCTAssertTrue(false, "oops")
        }
    }

    
}
