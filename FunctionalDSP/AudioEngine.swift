//
//  AudioEngine.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 4/14/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import AVFoundation

public protocol BufferQueueType {
    typealias BufferType
    var processor: BufferType -> Bool { get }
    
    func acquireBuffer() -> BufferType?
    func releaseBuffer(BufferType)
}

public final class AVAudioPCMBufferQueue: BufferQueueType {
    typealias BufferType = AVAudioPCMBuffer
    private let buffers: [AVAudioPCMBuffer]
    private var availableBuffers: [AVAudioPCMBuffer]
    private(set) public var processor: AVAudioPCMBuffer -> Bool
    private var semaphore: dispatch_semaphore_t
    
    public init(audioFormat: AVAudioFormat, bufferCount: Int, bufferLength: Int, processor bufferProcessor: AVAudioPCMBuffer -> Bool) {
        var allBuffers = [AVAudioPCMBuffer]()
        for i in 0..<bufferCount {
            allBuffers.append(AVAudioPCMBuffer(PCMFormat: audioFormat, frameCapacity: AVAudioFrameCount(bufferLength)))
        }
        buffers = allBuffers
        availableBuffers = [AVAudioPCMBuffer]()
        
        processor = bufferProcessor
        semaphore = dispatch_semaphore_create(0)
    }
    
    private var rq: dispatch_queue_t = dispatch_queue_create("com.supermegaultragroovy.rq", DISPATCH_QUEUE_SERIAL)
    
    public func acquireBuffer() -> AVAudioPCMBuffer? {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER)
        
        var available: AVAudioPCMBuffer?
        dispatch_sync(rq) {
            if self.availableBuffers.count > 0 {
                available = self.availableBuffers.removeAtIndex(0)
            }
        }
        return available
    }
    
    public func releaseBuffer(buffer: AVAudioPCMBuffer) {
        dispatch_async(rq) {
            if self.processor(buffer) {
                self.availableBuffers.append(buffer)
            }
            dispatch_semaphore_signal(self.semaphore)
        }
    }
    
    public func prime() {
        for buffer in buffers {
            releaseBuffer(buffer)
        }
    }
}

let kActiveBufferCount = 2
let kSamplesPerBuffer = 4096

public func fillFloats(floats: UnsafeMutablePointer<Float>, withSignal signal: Signal, ofLength length: Int, startingAtSample startSample: Int) {
    for i in 0..<length {
        floats[i] = signal(startSample + i)
    }
}

public func fillPCMBuffer(audioBuffer: AVAudioPCMBuffer, withBlock block: Block, atStartSample startSample: Int) {
    let channelCount = Int(audioBuffer.format.channelCount)
    assert( channelCount == block.outputCount )
    
    let outputs = block.process([])
    
    for i in 0..<channelCount {
        fillFloats(audioBuffer.floatChannelData[i], withSignal: outputs[i], ofLength: Int(audioBuffer.frameCapacity), startingAtSample: startSample)
    }
    
    audioBuffer.frameLength = audioBuffer.frameCapacity
}

public func playTone(playerNode: AVAudioPlayerNode) {
    let sampleRate = playerNode.outputFormatForBus(0).sampleRate
    let channelCount = playerNode.outputFormatForBus(0).channelCount
    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)
    
    let whiteBlock = Block(inputCount: 0, outputCount: 1, process: { _ in [whiteNoise()] })
    let filterBlock = Block(inputCount: 1, outputCount: 1, process: { inputs in inputs.map { pinkFilter($0) } } )
    
    let pinkNoise = whiteBlock -- filterBlock -< identity(Int(channelCount))
    
    var sampleTime = 0
    let theQueue = AVAudioPCMBufferQueue(audioFormat: audioFormat, bufferCount: kActiveBufferCount, bufferLength: kSamplesPerBuffer) { audioBuffer in
        fillPCMBuffer(audioBuffer, withBlock: pinkNoise, atStartSample: sampleTime)
        sampleTime += Int(audioBuffer.frameLength)
        return true
    }
    
    theQueue.prime()
    
    let playbackQueue = dispatch_queue_create("com.supermegaultragroovy.playerQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async( playbackQueue ) {
        while let audioBuffer = theQueue.acquireBuffer() {
            playerNode.scheduleBuffer(audioBuffer, atTime: nil, options: nil) {
                theQueue.releaseBuffer(audioBuffer)
            }
        }
        
        println( "all done. shutting down." )
    }
}