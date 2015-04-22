//
//  AudioEngine.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 4/14/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import AVFoundation

public protocol QueueableBufferType {
    typealias BufferType
    var buffer: BufferType { get }
}

public protocol BufferQueueType {
    typealias BufferType
    var processor: BufferType -> Bool { get }
    
    func acquireBuffer() -> BufferType?
    func releaseBuffer(BufferType)
}

public struct Buffer: QueueableBufferType, Printable {
    typealias BufferType = AVAudioPCMBuffer
    public let buffer: AVAudioPCMBuffer
    public let index: Int
    
    public init(index: Int, audioFormat: AVAudioFormat, frameCapacity: Int) {
        buffer = AVAudioPCMBuffer(PCMFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCapacity))
        self.index = index
    }
    
    public var description: String {
        return "Buffer[\(index)] frames=\(buffer.frameLength) capacity=\(buffer.frameCapacity)"
    }
}

public final class BufferQueue: BufferQueueType {
    typealias BufferType = Buffer
    private let buffers: [Buffer]
    private var availableBuffers: [Buffer]
    public var processor: Buffer -> Bool
    private var semaphore: dispatch_semaphore_t
    
    public init(audioFormat: AVAudioFormat, bufferCount: Int, bufferLength: Int, processor bufferProcessor: Buffer -> Bool) {
        var allBuffers = [Buffer]()
        for i in 0..<bufferCount {
            allBuffers.append(Buffer(index: i, audioFormat: audioFormat, frameCapacity: bufferLength))
        }
        buffers = allBuffers
        availableBuffers = [Buffer]()
        
        processor = bufferProcessor
        semaphore = dispatch_semaphore_create(0)
    }
    
    private var rq: dispatch_queue_t = dispatch_queue_create("com.supermegaultragroovy.rq", DISPATCH_QUEUE_SERIAL)
    private var index = 0
    public func acquireBuffer() -> Buffer? {
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER)
        
        var available: Buffer?
        dispatch_sync(rq) {
            if self.buffers.count > 0 {
                available = self.availableBuffers.removeAtIndex(0)
            }
        }
        return available
    }
    
    public func releaseBuffer(buffer: Buffer) {
        dispatch_async(rq) {
            self.processor(buffer)
            self.availableBuffers.append(buffer)
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

public func playTone(playerNode: AVAudioPlayerNode) {
    
    let sampleRate = playerNode.outputFormatForBus(0).sampleRate
    let channelCount = playerNode.outputFormatForBus(0).channelCount
    let theWave = sineWave(Int(sampleRate), 1000.0)
    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount)
    
    var sampleTime = 0
    let theQueue = BufferQueue(audioFormat: audioFormat, bufferCount: kActiveBufferCount, bufferLength: kSamplesPerBuffer) { audioBuffer in
        let theAudioBuffer = audioBuffer.buffer
        theAudioBuffer.frameLength = 0
        
        let leftChannel = theAudioBuffer.floatChannelData[0]
        let rightChannel = theAudioBuffer.floatChannelData[1]
        for var sampleIndex = 0; sampleIndex < Int(theAudioBuffer.frameCapacity); sampleIndex++ {
            let sample = theWave(sampleTime)
            leftChannel[sampleIndex] = sample
            rightChannel[sampleIndex] = sample
            sampleTime++
        }
        theAudioBuffer.frameLength = theAudioBuffer.frameCapacity
        
        return true
    }
    
    theQueue.prime()
    
    let playbackQueue = dispatch_queue_create("com.supermegaultragroovy.playerQueue", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async( playbackQueue ) {
        while let audioBuffer = theQueue.acquireBuffer() {
            playerNode.scheduleBuffer(audioBuffer.buffer, atTime: nil, options: nil) {
                println("releasing \(audioBuffer)")
                theQueue.releaseBuffer(audioBuffer)
            }
        }
    }
}