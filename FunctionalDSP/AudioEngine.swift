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
    var buffers: [BufferType] { get }
}

public final class BufferQueue: BufferQueueType {
    typealias BufferType = AVAudioPCMBuffer
    public let buffers: [AVAudioPCMBuffer]
    
    public init(audioFormat: AVAudioFormat, bufferCount: Int, bufferLength: AVAudioFrameCount) {
        buffers = [AVAudioPCMBuffer](count: bufferCount, repeatedValue: AVAudioPCMBuffer(PCMFormat: audioFormat, frameCapacity: bufferLength))
        semaphore = dispatch_semaphore_create(bufferCount)
    }
    
    public var stop: Bool = false
    
    private var rq: dispatch_queue_t = dispatch_queue_create("com.supermegaultragroovy.rq", DISPATCH_QUEUE_CONCURRENT)
    private var semaphore: dispatch_semaphore_t
    private var index = 0
    public func acquireBuffer() -> AVAudioPCMBuffer? {
        if stop {
            return nil
        }
        
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER)
        
        var available: AVAudioPCMBuffer?
        dispatch_barrier_sync(rq) {
            available = self.buffers[self.index]
            self.index = (self.index + 1) % self.buffers.count
        }
        return available
    }
    
    public func releaseBuffer(buffer: AVAudioPCMBuffer) {
        dispatch_semaphore_signal(semaphore)
    }
}

let kActiveBufferCount = 2
let kSamplesPerBuffer: AVAudioFrameCount = 4096

public func playTone(playerNode: AVAudioPlayerNode) {
    let sampleRate = playerNode.outputFormatForBus(0).sampleRate
    
    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
    let theQueue = BufferQueue(audioFormat: audioFormat, bufferCount: kActiveBufferCount, bufferLength: kSamplesPerBuffer)
    
    var sampleTime = 0
    let theWave = sineWave(Int(sampleRate), 220.0)
    
    while let audioBuffer = theQueue.acquireBuffer() {
        let leftChannel = audioBuffer.floatChannelData[0]
        let rightChannel = audioBuffer.floatChannelData[1]
        for var sampleIndex = 0; sampleIndex < Int(audioBuffer.frameCapacity); sampleIndex++ {
            let sample = theWave(sampleTime+sampleIndex)
            leftChannel[sampleIndex] = sample
            rightChannel[sampleIndex] = sample
        }
        sampleTime += Int(audioBuffer.frameCapacity)
        audioBuffer.frameLength = audioBuffer.frameCapacity
        
        playerNode.scheduleBuffer(audioBuffer, atTime: nil, options: nil) {
            theQueue.releaseBuffer(audioBuffer)
        }
    }
}