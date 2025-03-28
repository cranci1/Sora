//
//  VTTSubtitlesLoader.swift
//  Sora
//
//  Created by Francesco on 15/02/25.
//

import Combine
import Foundation

struct SubtitleCue: Identifiable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    let text: String
}

class VTTSubtitlesLoader: ObservableObject {
    @Published var cues: [SubtitleCue] = []
    
    enum SubtitleFormat {
        case vtt
        case srt
        case unknown
    }
    
    func load(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let format = determineSubtitleFormat(from: url)
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let content = String(data: data, encoding: .utf8),
                  error == nil else { return }
            
            DispatchQueue.main.async {
                switch format {
                case .vtt:
                    self.cues = self.parseVTT(content: content)
                case .srt:
                    self.cues = self.parseSRT(content: content)
                case .unknown:
                    if content.trimmed.hasPrefix("WEBVTT") {
                        self.cues = self.parseVTT(content: content)
                    } else {
                        self.cues = self.parseSRT(content: content)
                    }
                }
            }
        }.resume()
    }
    
    private func determineSubtitleFormat(from url: URL) -> SubtitleFormat {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "vtt", "webvtt":
            return .vtt
        case "srt":
            return .srt
        default:
            return .unknown
        }
    }
    
    private func parseVTT(content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var index = 0
        
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line == "WEBVTT" {
                index += 1
                continue
            }
            
            if !line.contains("-->") {
                index += 1
                if index >= lines.count { break }
            }
            
            let timeLine = lines[index]
            let times = timeLine.components(separatedBy: "-->")
            if times.count < 2 {
                index += 1
                continue
            }
            
            let startTime = parseTimecode(times[0].trimmingCharacters(in: .whitespaces))
            let adjustedStartTime = max(startTime - 0.5, 0)
            let endTime = parseTimecode(times[1].trimmingCharacters(in: .whitespaces))
            let adjusteEndTime = max(endTime - 0.5, 0)
            index += 1
            var cueText = ""
            while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                cueText += lines[index] + "\n"
                index += 1
            }
            cues.append(SubtitleCue(startTime: adjustedStartTime, endTime: adjusteEndTime, text: cueText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return cues
    }
    
    private func parseSRT(content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let normalizedContent = content.replacingOccurrences(of: "\r\n", with: "\n")
                                      .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalizedContent.components(separatedBy: "\n\n")
        
        for block in blocks {
            let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
            guard lines.count >= 2 else { continue }
            
            let timeLine = lines[1]
            let times = timeLine.components(separatedBy: "-->")
            
            guard times.count >= 2 else { continue }
            
            let startTime = parseSRTTimecode(times[0].trimmingCharacters(in: .whitespaces))
            let adjustedStartTime = max(startTime - 0.5, 0)
            let endTime = parseSRTTimecode(times[1].trimmingCharacters(in: .whitespaces))
            let adjustedEndTime = max(endTime - 0.5, 0)
            
            var textLines = [String]()
            if lines.count > 2 {
                textLines = Array(lines[2...])
            }
            let text = textLines.joined(separator: "\n")
            
            cues.append(SubtitleCue(startTime: adjustedStartTime, endTime: adjustedEndTime, text: text))
        }
        
        return cues
    }
    
    private func parseTimecode(_ timeString: String) -> Double {
        let parts = timeString.components(separatedBy: ":")
        var seconds = 0.0
        if parts.count == 3,
           let h = Double(parts[0]),
           let m = Double(parts[1]),
           let s = Double(parts[2].replacingOccurrences(of: ",", with: ".")) {
            seconds = h * 3600 + m * 60 + s
        } else if parts.count == 2,
                  let m = Double(parts[0]),
                  let s = Double(parts[1].replacingOccurrences(of: ",", with: ".")) {
            seconds = m * 60 + s
        }
        return seconds
    }
    
    private func parseSRTTimecode(_ timeString: String) -> Double {
        let parts = timeString.components(separatedBy: ":")
        guard parts.count == 3 else { return 0 }
        
        let secondsParts = parts[2].components(separatedBy: ",")
        guard secondsParts.count == 2,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(secondsParts[0]),
              let milliseconds = Double(secondsParts[1]) else {
            return 0
        }
        
        return hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
    }
}
