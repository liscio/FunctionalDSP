//
//  AudioFileIO.swift
//  FunctionalDSP
//
//  Created by Christopher Liscio on 3/8/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Foundation
import AudioToolbox

func audioCallFailed(status: OSStatus) -> Bool {
    return status != noErr
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
    var audioFileRef: ExtAudioFileRef!
    let sampleRate: Int
    let channelCount: Int
    
    var nativeStreamDescription: AudioStreamBasicDescription {
        return AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: UInt32(kAudioFormatLinearPCM),
            mFormatFlags: UInt32(0),
            mBytesPerPacket: SampleType.audioByteSize,
            mFramesPerPacket: UInt32(1),
            mBytesPerFrame: UInt32(channelCount) * SampleType.audioByteSize,
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32( 8 * SampleType.audioByteSize ),
            mReserved: UInt32(0))
    }
    
    public init?(forWritingToURL url: NSURL, withSampleRate sampleRate: Int, channelCount: Int = 1) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        if let fileType = inferTypeFromURL(url) {
            if audioCallFailed(ExtAudioFileCreateWithURL(url, fileType, <#inStreamDesc: UnsafePointer<AudioStreamBasicDescription>#>, <#inChannelLayout: UnsafePointer<AudioChannelLayout>#>, <#inFlags: UInt32#>, <#outExtAudioFile: UnsafeMutablePointer<ExtAudioFileRef>#>)
        }
        return nil
    }
    
    func inferTypeFromURL(url: NSURL) -> AudioFileTypeID? {
        if let fileExtension = url.pathExtension?.lowercaseString {
            switch fileExtension {
            case "aif":
                return AudioFileTypeID(kAudioFileAIFFType)
            case "wav":
                return AudioFileTypeID(kAudioFileWAVEType)
            default:
                return nil
            }
        }
        return nil
    }
}

//func writeSamples(samples: [SampleType], toAudioFileAtURL url: NSURL) {
//    let audioFile = ExtAudioFileCreateWithURL(url)
//
//
//
//    ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof(clientFormat), &clientFormat)
//    ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_FileDataFormat, sizeof(fileFormat), &fileFormat)
//
//    let kWriteBufferSize = 16384
//    let bufferCount = samples.count / kWriteBufferSize
//    for i in 0..<bufferCount {
//        ExtAudioFileWrite(audioFile, framesToWrite, &buffer)
//    }
//
//    ExtAudioFileDispose(audioFile)
//}