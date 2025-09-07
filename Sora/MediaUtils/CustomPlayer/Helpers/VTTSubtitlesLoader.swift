//
//  VTTSubtitlesLoader.swift
//  Sora
//
//  Created by Francesco on 15/02/25.
//

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
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let responseData = data,
                  let subtitleContent = String(data: responseData, encoding: .utf8),
                  !subtitleContent.isEmpty,
                  error == nil else {
                DispatchQueue.main.async {
                    self.cues = []
                }
                return
            }
            
            let detectedFormat = self.determineSubtitleFormat(from: url)
            
            DispatchQueue.main.async {
                switch detectedFormat {
                case .vtt:
                    self.cues = self.parseVTT(content: subtitleContent)
                case .srt:
                    self.cues = self.parseSRT(content: subtitleContent)
                case .unknown:
                    if subtitleContent.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT") {
                        self.cues = self.parseVTT(content: subtitleContent)
                    } else {
                        self.cues = self.parseSRT(content: subtitleContent)
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
        let contentLines = content.components(separatedBy: .newlines)
        var subtitleCues: [SubtitleCue] = []
        var activeStartTime: Double?
        var activeEndTime: Double?
        var activeSubtitleText: String = ""
        var processingCueContent = false
        
        for (lineIndex, currentLine) in contentLines.enumerated() {
            let cleanedLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanedLine.isEmpty || cleanedLine == "WEBVTT" || cleanedLine.starts(with: "NOTE") {
                if processingCueContent && !activeSubtitleText.isEmpty {
                    if let beginTime = activeStartTime, let finishTime = activeEndTime {
                        subtitleCues.append(SubtitleCue(startTime: beginTime, endTime: finishTime, text: activeSubtitleText))
                    }
                    processingCueContent = false
                    activeStartTime = nil
                    activeEndTime = nil
                    activeSubtitleText = ""
                }
                continue
            }
            
            if cleanedLine.contains("-->") {
                if processingCueContent && !activeSubtitleText.isEmpty {
                    if let beginTime = activeStartTime, let finishTime = activeEndTime {
                        subtitleCues.append(SubtitleCue(startTime: beginTime, endTime: finishTime, text: activeSubtitleText))
                    }
                }
                
                let timeComponents = cleanedLine.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                if timeComponents.count == 2 {
                    activeStartTime = parseVTTTime(timeComponents[0])
                    activeEndTime = parseVTTTime(timeComponents[1])
                    activeSubtitleText = ""
                    processingCueContent = true
                }
            } else if processingCueContent {
                if !activeSubtitleText.isEmpty {
                    activeSubtitleText += "\n"
                }
                activeSubtitleText += cleanedLine
                
                let isFinalLine = lineIndex == contentLines.count - 1
                let followingLine = isFinalLine ? "" : contentLines[lineIndex + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if isFinalLine || followingLine.isEmpty || followingLine.contains("-->") {
                    if let beginTime = activeStartTime, let finishTime = activeEndTime {
                        subtitleCues.append(SubtitleCue(startTime: beginTime, endTime: finishTime, text: activeSubtitleText))
                        activeStartTime = nil
                        activeEndTime = nil
                        activeSubtitleText = ""
                        processingCueContent = false
                    }
                }
            }
        }
        
        return subtitleCues
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
            let endTime = parseSRTTimecode(times[1].trimmingCharacters(in: .whitespaces))
            
            var textLines = [String]()
            if lines.count > 2 {
                textLines = Array(lines[2...])
            }
            let text = textLines.joined(separator: "\n")
            
            cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
        }
        
        return cues
    }
    
    private func parseVTTTime(_ timeString: String) -> Double {
        let timeSegments = timeString.components(separatedBy: ":")
        guard timeSegments.count >= 2 else { return 0 }
        
        var hourValue = 0.0
        var minuteValue = 0.0
        var secondValue = 0.0
        
        if timeSegments.count == 3 {
            hourValue = Double(timeSegments[0]) ?? 0
            minuteValue = Double(timeSegments[1]) ?? 0
            let secondComponents = timeSegments[2].components(separatedBy: ".")
            secondValue = Double(secondComponents[0]) ?? 0
            if secondComponents.count > 1 {
                secondValue += Double("0." + secondComponents[1]) ?? 0
            }
        } else {
            minuteValue = Double(timeSegments[0]) ?? 0
            let secondComponents = timeSegments[1].components(separatedBy: ".")
            secondValue = Double(secondComponents[0]) ?? 0
            if secondComponents.count > 1 {
                secondValue += Double("0." + secondComponents[1]) ?? 0
            }
        }
        
        return hourValue * 3600 + minuteValue * 60 + secondValue
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
