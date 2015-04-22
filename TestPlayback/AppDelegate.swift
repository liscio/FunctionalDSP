//
//  AppDelegate.swift
//  TestPlayback
//
//  Created by Christopher Liscio on 4/14/15.
//  Copyright (c) 2015 SuperMegaUltraGroovy, Inc. All rights reserved.
//

import Cocoa
import FunctionalDSP
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        engine.attachNode(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: engine.mainMixerNode.inputFormatForBus(0))
        
        var error: NSError? = nil
        if !engine.startAndReturnError(&error) {
            NSLog("Error starting audio engine: \(error)")
        }
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
            playTone(self.playerNode)
        }
        
        playerNode.play()
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

