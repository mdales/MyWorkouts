//
//  SpeachManager.swift
//  MyWorkouts
//
//  Created by Michael Dales on 25/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import AVKit
import Foundation

class SpeachManager: NSObject, ObservableObject {

    let synthesizer = AVSpeechSynthesizer()

    func setup() throws {
        synthesizer.delegate = self
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
    }

    func speak(text: String) throws {
        let spokenPhrase = AVSpeechUtterance(string: text)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(true)
        self.synthesizer.speak(spokenPhrase)
    }
}

extension SpeachManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false)
        } catch {
            print("Failed to deactivate audio: \(error)")
        }
    }
}
