//: Playground - noun: a place where people can play

import FunctionalDSP
import AVFoundation

let engine = AVAudioEngine()
let playerNode = AVAudioPlayerNode()

let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)

engine.attachNode(playerNode)
engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)

var error: NSError? = nil
if !engine.startAndReturnError(&error) {
    NSLog("Error starting audio engine: \(error)")
}

dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
    playTone(playerNode)
}

playerNode.pan = 0.5
playerNode.play()
