//
//  Speech.swift
//  CoinPrice
//
//  Created by Joey Young on 2022/1/13.
//

import Cocoa
import AVFoundation
import MediaPlayer

class Speech: NSObject {
    var text = "1234567890"
    
    // Code of text-to-speech
    let loop = RunLoop.current
    let synth = NSSpeechSynthesizer()
    
    public func speech(text: String) {
        DispatchQueue.global().async {
            self.synth.startSpeaking(text)
            let mode = self.loop.currentMode ?? RunLoop.Mode.default
            while self.loop.run(mode: mode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) && self.synth.isSpeaking {}
        }
        
    }
    
    public func play() {
        
        for v in NSSpeechSynthesizer.availableVoices {
            let attrs = NSSpeechSynthesizer.attributes(forVoice: v)
            if attrs[NSSpeechSynthesizer.VoiceAttributeKey(rawValue: "VoiceLanguage")] as? String == "zh_CN" {
                synth.setVoice(v)
                break
            }
        }
        
        speech(text: text)
        
    }
    
    public func pause() {
        // 暂停朗读
        
        
    }
    
    public func continuePlay() {
        // 继续朗读
        
        
    }

    public func stopPlay() {
        // 停止之后，继续是无法继续播放的，因为不是暂停
        
    }
    
    public func isSpeaking() -> Bool {
        return synth.isSpeaking

    }
}

