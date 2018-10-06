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
    associatedtype BufferType
    var processor: (BufferType) -> Bool { get }
    
    func acquireBuffer() -> BufferType?
    func releaseBuffer(_: BufferType)
}

public final class AVAudioPCMBufferQueue: BufferQueueType {
    public typealias BufferType = AVAudioPCMBuffer
    fileprivate let buffers: [AVAudioPCMBuffer]
    fileprivate var availableBuffers: [AVAudioPCMBuffer]
    fileprivate(set) public var processor: (AVAudioPCMBuffer) -> Bool
    fileprivate var semaphore: DispatchSemaphore
    
    public init(audioFormat: AVAudioFormat, bufferCount: Int, bufferLength: Int, processor bufferProcessor: @escaping (AVAudioPCMBuffer) -> Bool) {
        var allBuffers = [AVAudioPCMBuffer]()
        for _ in 0..<bufferCount {
            allBuffers.append(AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(bufferLength)))
        }
        buffers = allBuffers
        availableBuffers = [AVAudioPCMBuffer]()
        
        processor = bufferProcessor
        semaphore = DispatchSemaphore(value: 0)
    }
    
    fileprivate var rq: DispatchQueue = DispatchQueue(label: "com.supermegaultragroovy.rq", attributes: [])
    
    public func acquireBuffer() -> AVAudioPCMBuffer? {
        self.semaphore.wait(timeout: DispatchTime.distantFuture)
        
        var available: AVAudioPCMBuffer?
        rq.sync {
            if self.availableBuffers.count > 0 {
                available = self.availableBuffers.remove(at: 0)
            }
        }
        return available
    }
    
    public func releaseBuffer(_ buffer: AVAudioPCMBuffer) {
        rq.async {
            if self.processor(buffer) {
                self.availableBuffers.append(buffer)
            }
            self.semaphore.signal()
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

public func fillFloats(_ floats: UnsafeMutablePointer<Float>, withSignal signal: Signal, ofLength length: Int, startingAtSample startSample: Int) {
    for i in 0..<length {
        floats[i] = signal(startSample + i)
    }
}

public func fillPCMBuffer(_ audioBuffer: AVAudioPCMBuffer, withBlock block: Block, atStartSample startSample: Int) {
    let channelCount = Int(audioBuffer.format.channelCount)
    assert( channelCount == block.outputCount )
    
    let outputs = block.process([])
    
    for i in 0..<channelCount {
        fillFloats((audioBuffer.floatChannelData?[i])!, withSignal: outputs[i], ofLength: Int(audioBuffer.frameCapacity), startingAtSample: startSample)
    }
    
    audioBuffer.frameLength = audioBuffer.frameCapacity
}

public func playTone(_ playerNode: AVAudioPlayerNode) {
    let sampleRate = playerNode.outputFormat(forBus: 0).sampleRate
    let channelCount = playerNode.outputFormat(forBus: 0).channelCount
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
    
    let playbackQueue = DispatchQueue(label: "com.supermegaultragroovy.playerQueue", attributes: []);
    
    playbackQueue.async {
        while let audioBuffer = theQueue.acquireBuffer() {
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: AVAudioPlayerNodeBufferOptions()) {
                theQueue.releaseBuffer(audioBuffer)
            }
        }
        
        print( "all done. shutting down." )
    }
}
