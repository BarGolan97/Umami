// SoundPlayer.swift
// Utility to play short UI sounds (like pop.wav)

import Foundation
import AudioToolbox

enum SoundPlayer {
    private static var popID: SystemSoundID = 0
    private static var isLoaded = false
    private static var timesUpID: SystemSoundID = 0
    private static var isTimesUpLoaded = false
    private static var sweeshID: SystemSoundID = 0
    private static var isSweeshLoaded = false

    private static func ensureLoaded() {
        guard !isLoaded else { return }
        if let url = Bundle.main.url(forResource: "Pop", withExtension: "wav") {
            var id: SystemSoundID = 0
            let status = AudioServicesCreateSystemSoundID(url as CFURL, &id)
            if status == kAudioServicesNoError {
                popID = id
                isLoaded = true
            }
        }
    }

    private static func ensureTimesUpLoaded() {
        guard !isTimesUpLoaded else { return }
        if let url = Bundle.main.url(forResource: "TimesUp", withExtension: "wav") {
            var id: SystemSoundID = 0
            let status = AudioServicesCreateSystemSoundID(url as CFURL, &id)
            if status == kAudioServicesNoError {
                timesUpID = id
                isTimesUpLoaded = true
            }
        }
    }

    private static func ensureSweeshLoaded() {
        guard !isSweeshLoaded else { return }
        if let url = Bundle.main.url(forResource: "Sweesh", withExtension: "wav") {
            var id: SystemSoundID = 0
            let status = AudioServicesCreateSystemSoundID(url as CFURL, &id)
            if status == kAudioServicesNoError {
                sweeshID = id
                isSweeshLoaded = true
            }
        }
    }

    static func playPop() {
        ensureLoaded()
        if isLoaded {
            AudioServicesPlaySystemSound(popID)
        }
    }
    
    static func playTimesUp() {
        ensureTimesUpLoaded()
        if isTimesUpLoaded {
            AudioServicesPlaySystemSound(timesUpID)
        }
    }

    static func playSweesh() {
        ensureSweeshLoaded()
        if isSweeshLoaded {
            AudioServicesPlaySystemSound(sweeshID)
        } else {
            playPop()
        }
    }
}
