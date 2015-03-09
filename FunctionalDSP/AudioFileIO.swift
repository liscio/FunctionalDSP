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

func audioCallSucceeded(status: OSStatus) -> Bool {
    return status != noErr
}

func audioCallFailed(status: OSStatus) -> OSStatus? {
    if ( status != noErr ) {
        return status
    }
    return nil
}

extension SampleType {
    static var audioByteSize: UInt32 {
        return UInt32(sizeof(self))
    }
}

/*
    destFormat.mSampleRate = sampleRate;
    destFormat.mFormatID = kAudioFormatLinearPCM;
    
    if ( fileType == kAudioFileCAFType ) {
        // The CAF type allows us to have the closest to 1:1 correspondence between single precision real vectors and audio files, because of its ability to store floats.
        // We choose to specify Little Endian floats because they are native on Intel and ARM CPUs. (Using the native packed floats bitflag would be a mistake, as it would differ between platforms.)
        destFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    } else {
        // Both AIFF and WAV file formats expect signed ints
        destFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    }
    
    if ( fileType == kAudioFileAIFFType ) {
        // For historical/format reasons, AIFF files are also big endian.
        destFormat.mFormatFlags |= kAudioFormatFlagIsBigEndian;
    }
    
    destFormat.mFramesPerPacket = 1;
    destFormat.mChannelsPerFrame = 1;
    destFormat.mBitsPerChannel = (UInt32)bitDepth;
    destFormat.mBytesPerFrame = (UInt32)(bitDepth / 8);
    destFormat.mBytesPerPacket = destFormat.mBytesPerFrame * destFormat.mFramesPerPacket;
*/

public class AudioFile {
    /// The audio file reference (used internally)
    var audioFileID = AudioFileID()
    var audioConverter = AudioConverterRef()
    let sampleRate: Int
    let channelCount: Int
    let bitDepth: Int
    var fileType: AudioFileTypeID = 0
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
        let endianFlag: Int = (Int(fileType) == kAudioFileAIFFType ? kAudioFormatFlagIsBigEndian : 0)
        let bytesPerSample: Int = bitDepth / 8
        return AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: UInt32(kAudioFormatLinearPCM),
            mFormatFlags: UInt32(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | endianFlag),
            mBytesPerPacket: UInt32(1 * SampleType.audioByteSize),
            mFramesPerPacket: UInt32(1),
            mBytesPerFrame: UInt32(channelCount * bytesPerSample),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(bytesPerSample * 8),
            mReserved: UInt32(0))
    }
    
    public init?(forWritingToURL url: NSURL, withBitDepth bitDepth: Int, sampleRate: Int, channelCount: Int = 1) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        
        assert(channelCount == 1, "Sorry, cannot (yet) support more than 1 channel output")

        if let fileType = inferTypeFromURL(url) {
            self.fileType = fileType
            
            var sourceFormat = nativeStreamDescription
            var destinationFormat = fileStreamDescription
            
            if let status = audioCallFailed(AudioFileCreateWithURL(url as CFURL, self.fileType, &destinationFormat, UInt32(kAudioFileFlags_EraseFile), &audioFileID)) {
                println( "Failed to open audio file for writing with status \(status): \(url)" )
                return nil;
            }
            
            if let status = audioCallFailed(AudioConverterNew(&sourceFormat, &destinationFormat, &audioConverter)) {
                println( "Failed to create audio converter. \(status)" )
                return nil;
            }
            
            fileOpened = true
        } else {
            println( "Failed to infer audio file type for file: \(url)" )
            return nil
        }
    }
    
    func destroyAudioObjects() {
        if let status = audioCallFailed(AudioConverterDispose(audioConverter)) {
            println("Failed to dispose audio converter. \(status)")
        }
        audioConverter = AudioConverterRef()
        
        if let status = audioCallFailed(AudioFileClose(audioFileID)) {
            println("Failed to close audio file. \(status)")
        }
        audioFileID = AudioFileID()
        fileOpened = false
    }
    
    deinit {
        if fileOpened {
            destroyAudioObjects()
        }
    }
    
    public func close() {
        destroyAudioObjects()
    }
    
    var writeBufferSize = 0
    var writeBuffer: UnsafeMutablePointer<UInt8> = nil
    
    var fileWritePosition: Int64 = 0
    
    public func writeSamples(samples: [SampleType]) -> Bool {
        assert(fileOpened)
        
        let outputByteSize = samples.count * Int(fileStreamDescription.mBytesPerFrame)
        
        if writeBuffer != nil && writeBufferSize < outputByteSize {
            writeBuffer.dealloc(writeBufferSize)
            writeBufferSize = 0
            writeBuffer = nil
        }
        if writeBuffer == nil {
            writeBufferSize = outputByteSize
            writeBuffer = UnsafeMutablePointer.alloc(writeBufferSize)
        }
        
        var convertedSize = UInt32(outputByteSize)
        if let status = audioCallFailed(AudioConverterConvertBuffer(audioConverter, UInt32(samples.count * sizeof(SampleType)), samples, &convertedSize, writeBuffer)) {
            println( "Failed to convert audio data for writing. \(status)" )
            return false
        }
        
        if let status = audioCallFailed(AudioFileWriteBytes(audioFileID, Boolean(0), fileWritePosition, &convertedSize, writeBuffer)) {
            println( "Failed to write audio data to file. \(status)" )
            return false
        }
        
        return true
    }
    
    func inferTypeFromURL(url: NSURL) -> AudioFileTypeID? {
        if let fileExtension = url.pathExtension?.lowercaseString {
            switch fileExtension.lowercaseString {
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