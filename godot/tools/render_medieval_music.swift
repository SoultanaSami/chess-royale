#!/usr/bin/swift
// Renders two original, loop-ready game cues with the macOS General MIDI DLS.
// Runtime distribution contains only the rendered WAVs, never Apple's sound bank.
import AVFoundation
import Foundation

struct Event {
    let frame: Int64
    let sampler: Int
    let note: UInt8
    let velocity: UInt8
    let on: Bool
}
struct Track {
    let program: UInt8
    let reverb: Float
}

let sampleRate: Double = 44_100
let arguments = Array(CommandLine.arguments.dropFirst())
let bpm = Double(arguments.first ?? "66") ?? 66
let output = URL(fileURLWithPath: arguments.dropFirst().first ?? "/tmp/war-room.wav")
let battleCue = output.lastPathComponent.localizedCaseInsensitiveContains("battle")
let samplesPerBeat = Int64(sampleRate * 60.0 / bpm)
let bars = 32
let beats = bars * 4
let totalFrames = Int64(beats) * samplesPerBeat
let fadeFrames = Int64(sampleRate * 1.8)
let dls = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
let tracks = [Track(program: 48, reverb: 17), Track(program: 42, reverb: 14), Track(program: 46, reverb: 14), Track(program: 52, reverb: 20), Track(program: 47, reverb: 10)]
let harmonies: [[UInt8]] = [
    [50, 57, 62, 65], // D minor
    [46, 53, 58, 62], // B-flat
    [41, 48, 53, 57], // F
    [43, 48, 52, 55], // C
    [43, 50, 55, 58], // G minor
    [46, 53, 58, 62], // B-flat
    [43, 48, 52, 55], // C, unresolved/modal
    [50, 57, 62, 65]  // D minor, seamless opening
]
let motifs: [[UInt8]] = [
    [74, 69, 72, 77, 74, 69, 67, 69],
    [72, 67, 70, 74, 72, 69, 65, 67],
    [77, 72, 74, 81, 77, 74, 72, 69],
    [74, 69, 72, 77, 76, 72, 69, 74]
]

var events: [Event] = []
func add(_ sampler: Int, _ note: UInt8, _ velocity: UInt8, _ startBeat: Double, _ lengthBeats: Double) {
    let start = max(Int64(0), Int64(startBeat * Double(samplesPerBeat)))
    let end = min(totalFrames - 1, Int64((startBeat + lengthBeats) * Double(samplesPerBeat)))
    guard end > start else { return }
    let performanceVelocity = battleCue ? min(40, Int(velocity) + (sampler == 4 ? 5 : 3)) : Int(velocity)
    events.append(Event(frame: start, sampler: sampler, note: note, velocity: UInt8(performanceVelocity), on: true))
    events.append(Event(frame: end, sampler: sampler, note: note, velocity: 0, on: false))
}

for bar in 0..<bars {
    let barBeat = Double(bar * 4)
    let chord = harmonies[bar % harmonies.count]
    let phrase = bar / 4
    let variation = phrase % 4

    // Quiet, sustained strings; the upper harmony is deliberately sparse.
    add(0, chord[0], 24, barBeat + 0.08, 3.7)
    add(0, chord[2], 20, barBeat + 0.12, 3.62)
    if bar % 2 == 0 { add(0, chord[3], 17, barBeat + 0.22, 3.48) }

    // A very soft cello countermelody leaves rests for concentration.
    if bar % 2 == 0 {
        let motif = motifs[variation]
        let pick = (bar * 2 + (phrase % 2)) % motif.count
        add(1, motif[pick], 20 + UInt8(variation % 3), barBeat + 0.75, 2.2)
        if bar % 4 == 2 { add(1, motif[(pick + 2) % motif.count], 18, barBeat + 3.1, 0.75) }
    }

    // Gentle harp: occasional broken chord, with changing gaps in each phrase.
    let arpeggio = [chord[1], chord[2], chord[3], UInt8(min(Int(chord[3]) + 7, 84))]
    if (bar + variation) % 4 != 3 {
        for beat in 0..<4 {
            if beat == 2 && bar % 4 == 1 { continue }
            let note = arpeggio[(beat + variation) % arpeggio.count]
            let velocity: UInt8 = beat == 0 ? 25 : 19
            add(2, note, velocity, barBeat + Double(beat) + 0.12, beat == 1 ? 0.62 : 0.88)
        }
    }

    // Wordless, very quiet choir appears only at the turn of four-bar phrases.
    if bar % 4 == 0 {
        add(3, chord[0] + 12, 11, barBeat + 1.0, 2.6)
        add(3, chord[2] + 12, 9, barBeat + 1.05, 2.5)
    }

    // The timpani marks every eight-bar section once; no trailer-style hits.
    if bar % 8 == 0 {
        add(4, 38, 17, barBeat + 0.04, 0.38)
        if bar > 0 { add(4, 45, 10, barBeat + 2.0, 0.28) }
    }
}
events.sort { $0.frame == $1.frame ? (!$0.on && $1.on) : $0.frame < $1.frame }

let engine = AVAudioEngine()
var samplers: [AVAudioUnitSampler] = []
var reverbs: [AVAudioUnitReverb] = []
for track in tracks {
    let sampler = AVAudioUnitSampler()
    engine.attach(sampler)
    try sampler.loadSoundBankInstrument(at: dls, program: track.program, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(kAUSampler_DefaultBankLSB))
    let reverb = AVAudioUnitReverb()
    reverb.loadFactoryPreset(.largeHall)
    reverb.wetDryMix = track.reverb
    engine.attach(reverb)
    engine.connect(sampler, to: reverb, format: nil)
    engine.connect(reverb, to: engine.mainMixerNode, format: nil)
    samplers.append(sampler)
    reverbs.append(reverb)
}
let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 2, interleaved: true)!
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
engine.mainMixerNode.outputVolume = 0.72
try engine.start()
FileManager.default.createFile(atPath: output.path, contents: nil)
let pcmFile = try FileHandle(forUpdating: output)
func writeUInt32(_ value: UInt32) throws {
    var little = value.littleEndian
    try pcmFile.write(contentsOf: Data(bytes: &little, count: MemoryLayout<UInt32>.size))
}
func writeUInt16(_ value: UInt16) throws {
    var little = value.littleEndian
    try pcmFile.write(contentsOf: Data(bytes: &little, count: MemoryLayout<UInt16>.size))
}
try pcmFile.write(contentsOf: Data("RIFF".utf8))
try writeUInt32(0)
try pcmFile.write(contentsOf: Data("WAVEfmt ".utf8))
try writeUInt32(16)
try writeUInt16(1) // PCM
try writeUInt16(2) // stereo
try writeUInt32(UInt32(sampleRate))
try writeUInt32(UInt32(sampleRate) * 4)
try writeUInt16(4)
try writeUInt16(16)
try pcmFile.write(contentsOf: Data("data".utf8))
try writeUInt32(0)
var dataByteCount: UInt32 = 0
let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4096)!
var cursor: Int64 = 0
var eventIndex = 0
var peakSample: Float = 0
while cursor < totalFrames {
    while eventIndex < events.count && events[eventIndex].frame == cursor {
        let event = events[eventIndex]
        if event.on {
            samplers[event.sampler].startNote(event.note, withVelocity: event.velocity, onChannel: 0)
        } else {
            samplers[event.sampler].stopNote(event.note, onChannel: 0)
        }
        eventIndex += 1
    }
    let nextEventFrame = eventIndex < events.count ? events[eventIndex].frame : totalFrames
    let count = AVAudioFrameCount(min(Int64(4096), max(1, min(totalFrames - cursor, nextEventFrame - cursor))))
    switch try engine.renderOffline(count, to: buffer) {
    case .success:
        let length = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        let channelsData = buffer.floatChannelData!
        for frame in 0..<length {
            let absolute = cursor + Int64(frame)
            let fadeIn = min(1.0, Double(absolute) / Double(fadeFrames))
            let fadeOut = min(1.0, Double(totalFrames - absolute) / Double(fadeFrames))
            let gain = Float(min(fadeIn, fadeOut))
            for channel in 0..<channels {
                channelsData[channel][frame] *= gain
                peakSample = max(peakSample, abs(channelsData[channel][frame]))
            }
        }
        outputBuffer.frameLength = AVAudioFrameCount(length)
        let outputSamples = outputBuffer.int16ChannelData![0]
        for frame in 0..<length {
            for channel in 0..<channels {
                let sample = max(-1.0, min(1.0, Double(channelsData[channel][frame])))
                outputSamples[frame * channels + channel] = Int16(sample * Double(Int16.max))
            }
        }
        let chunk = Data(bytes: outputSamples, count: length * channels * MemoryLayout<Int16>.size)
        try pcmFile.write(contentsOf: chunk)
        dataByteCount += UInt32(chunk.count)
        cursor += Int64(length)
    case .cannotDoInCurrentContext:
        continue
    case .insufficientDataFromInputNode:
        throw NSError(domain: "MusicRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unexpected offline input request at frame \(cursor)"])
    case .error:
        fatalError("Audio offline renderer failed at frame \(cursor)")
    @unknown default:
        fatalError("Unknown audio renderer result")
    }
}
engine.stop()
try pcmFile.synchronize()
try pcmFile.seek(toOffset: 44)
var renderedAudio = try pcmFile.read(upToCount: Int(dataByteCount)) ?? Data()
let normalizationGain = peakSample > 0 ? 0.42 / Double(peakSample) : 1.0
renderedAudio.withUnsafeMutableBytes { rawBuffer in
	let samples = rawBuffer.bindMemory(to: Int16.self)
	for index in samples.indices {
		let normalized = (Double(samples[index]) * normalizationGain).rounded()
		samples[index] = Int16(max(Double(Int16.min), min(Double(Int16.max), normalized)))
	}
}
try pcmFile.seek(toOffset: 44)
try pcmFile.write(contentsOf: renderedAudio)
try pcmFile.seek(toOffset: 4)
try writeUInt32(36 + dataByteCount)
try pcmFile.seek(toOffset: 40)
try writeUInt32(dataByteCount)
try pcmFile.close()
print("Rendered \(output.path): \(bars) bars at \(Int(bpm)) BPM, \(Int(totalFrames)) frames, peak \(peakSample).")
