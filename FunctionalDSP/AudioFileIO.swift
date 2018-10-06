//
//  AudioFileIO.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 3/8/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import CoreAudio
import AudioToolbox

func audioCallFailed(_ status: OSStatus) -> OSStatus? {
    if ( status != noErr ) {
        return status
    }
    return nil
}

extension SampleType {
    static var audioByteSize: UInt32 {
        return UInt32(MemoryLayout.size(ofValue: self))
    }
}

public protocol AudioConverter {
    var audioConverter: AudioConverterRef? { get }
    
    var inputStreamDescription: AudioStreamBasicDescription { get set }
    var outputStreamDescription: AudioStreamBasicDescription { get set }
}

open class LPCMAudioConverter: AudioConverter {
    public var audioConverter: AudioConverterRef? = nil
    
    open var inputStreamDescription: AudioStreamBasicDescription
    open var outputStreamDescription: AudioStreamBasicDescription
    
    public init?(inputFormat: AudioStreamBasicDescription, outputFormat: AudioStreamBasicDescription) {
        inputStreamDescription = inputFormat
        outputStreamDescription = outputFormat
        
        if let status = audioCallFailed(AudioConverterNew(&inputStreamDescription, &outputStreamDescription, &audioConverter)) {
            print( "Failed to create audio converter. \(status)" )
            return nil;
        }
    }
    
    deinit {
        if let status = audioCallFailed(AudioConverterDispose(audioConverter!)) {
            print("Failed to dispose audio converter. \(status)")
        }
        audioConverter = nil
    }
    
    open func convertSamplesInBuffer(_ inputBuffer: UnsafeRawPointer, withLength inputLength: Int, toBuffer outputBuffer: UnsafeMutableRawPointer, withLength outputLength: inout Int) {
        var uOutputLength = UInt32(outputLength)
        if let status = audioCallFailed(AudioConverterConvertBuffer(audioConverter!, UInt32(inputLength), inputBuffer, &uOutputLength, outputBuffer)) {
            print( "Failed to convert audio data for writing. \(status)" )
        }
        outputLength = Int(uOutputLength)
    }
}

open class AudioFile {
    var audioFileID: AudioFileID? = nil
    var audioConverter: LPCMAudioConverter!
    var fileType: AudioFileTypeID = 0
    
    open let sampleRate: Int
    open let channelCount: Int
    open let bitDepth: Int

    var fileOpened: Bool = false
    
    var nativeStreamDescription: AudioStreamBasicDescription {
        return AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: UInt32(kAudioFormatLinearPCM),
            mFormatFlags: UInt32(kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked),
            mBytesPerPacket: SampleType.audioByteSize,
            mFramesPerPacket: UInt32(1),
            mBytesPerFrame: UInt32(channelCount) * SampleType.audioByteSize,
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32( 8 * SampleType.audioByteSize ),
            mReserved: UInt32(0))
    }
    
    var fileStreamDescription: AudioStreamBasicDescription {
        let endianFlag: Int = (Int(fileType) == Int(kAudioFileAIFFType) ? Int(kAudioFormatFlagIsBigEndian) : 0)
        let bytesPerSample: Int = bitDepth / 8
        return AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: UInt32(kAudioFormatLinearPCM),
            mFormatFlags: UInt32(Int(kAudioFormatFlagIsSignedInteger) | Int(kAudioFormatFlagIsPacked) | endianFlag),
            mBytesPerPacket: UInt32(channelCount * bytesPerSample),
            mFramesPerPacket: UInt32(1),
            mBytesPerFrame: UInt32(channelCount * bytesPerSample),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(bytesPerSample * 8),
            mReserved: UInt32(0))
    }
    
    public init?(forWritingToURL url: URL, withBitDepth bitDepth: Int, sampleRate: Int, channelCount: Int = 1) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        
        assert(channelCount == 1, "Sorry, cannot (yet) support more than 1 channel output")

        if let fileType = inferTypeFromURL(url) {
            self.fileType = fileType
            
            var destinationFormat = fileStreamDescription
            if let status = audioCallFailed(AudioFileCreateWithURL(url as CFURL, self.fileType, &destinationFormat, AudioFileFlags.eraseFile, &audioFileID)) {
                print( "Failed to open audio file for writing with status \(status): \(url)" )
                return nil;
            }
            
            self.audioConverter = LPCMAudioConverter(inputFormat: nativeStreamDescription, outputFormat: fileStreamDescription)
            if self.audioConverter == nil {
                print( "Failed to create audio converter when opening file: \(url)" )
                return nil
            }
            
            fileOpened = true
        } else {
            print( "Failed to infer audio file type for file: \(url)" )
            return nil
        }
    }
    
    func destroyAudioObjects() {
        if let status = audioCallFailed(AudioFileClose(audioFileID!)) {
            print("Failed to close audio file. \(status)")
        }
        audioFileID = nil
        fileOpened = false
    }
    
    deinit {
        if fileOpened {
            destroyAudioObjects()
        }
        
        if writeBuffer != nil {
            destroyAudioBuffer()
        }
    }
    
    open func close() {
        destroyAudioObjects()
    }
    
    var writeBufferSize = 0
    var writeBuffer: UnsafeMutablePointer<UInt8>? = nil
    
    func destroyAudioBuffer() {
        writeBuffer?.deallocate(capacity: writeBufferSize)
        writeBufferSize = 0
        writeBuffer = nil
    }
    
    func allocateAudioBufferWithSize(_ size: Int) {
        writeBufferSize = size
        writeBuffer = UnsafeMutablePointer.allocate(capacity: writeBufferSize)
    }
    
    var fileWritePosition: Int64 = 0
    
    open func writeSamples(_ samples: [SampleType]) -> Bool {
        assert(fileOpened)
        
        let outputByteSize = samples.count * Int(fileStreamDescription.mBytesPerFrame)
        
        if writeBuffer != nil && writeBufferSize < outputByteSize {
            destroyAudioBuffer()
        }
        if writeBuffer == nil {
            allocateAudioBufferWithSize(outputByteSize)
        }

        var convertedSize = outputByteSize
        audioConverter.convertSamplesInBuffer(samples, withLength: samples.count * MemoryLayout<SampleType>.size, toBuffer: writeBuffer!, withLength: &convertedSize)
        
        var uSize = UInt32(convertedSize)
        if let status = audioCallFailed(AudioFileWriteBytes(audioFileID!, false, fileWritePosition, &uSize, writeBuffer!)) {
            print( "Failed to write audio data to file. \(status)" )
            return false
        }
        
        fileWritePosition = fileWritePosition + Int64(convertedSize)
        
        return true
    }
    
    func inferTypeFromURL(_ url: URL?) -> AudioFileTypeID? {
        if let fileExtension = url?.pathExtension.lowercased() {
            switch fileExtension.lowercased() {
            case "aif", "aiff":
                return AudioFileTypeID(kAudioFileAIFFType)
            case "wav", "wave":
                return AudioFileTypeID(kAudioFileWAVEType)
            default:
                return nil
            }
        }
        return nil
    }
}
