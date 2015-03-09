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
    return mix_2( sineWave(sampleRate, f1), sineWave(sampleRate, f2) )
}

class FunctionalDSPTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDTMF() {
        let sampleRate = 44100
        
        let phoneNumber = [8, 6, 7, 5, 3, 0, 9]
        let signals = phoneNumber.map { dtmfTone($0, sampleRate) }
        
        let toneDuration = sampleRate
        let samples = signals.map { getOutput($0, 0, toneDuration) }.reduce([], combine: +)
        
        if let af = AudioFile(forWritingToURL: NSURL(fileURLWithPath: "/Users/chris/testfile.wav")!, withBitDepth: 16, sampleRate: 44100, channelCount: 1) {
            af.writeSamples(samples)
            af.close()
            XCTAssertTrue(true, "yay")
        } else {
            XCTAssertTrue(false, "oops")
        }
    }

    
}
