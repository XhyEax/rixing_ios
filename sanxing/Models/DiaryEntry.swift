// Models/DiaryEntry.swift — 日记条目（一天可多条）
import Foundation
import SwiftData

@Model
final class DiaryEntry {
    // 默认值是 CloudKit 同步的硬性要求（每个属性须可选或有默认值）；实际值由 init 覆盖
    var createdAt: Date = Date.now
    var text: String = ""
    var mood: Int = 0   // 0=未设；1...5 由差到好

    init(createdAt: Date = .now, text: String = "", mood: Int = 0) {
        self.createdAt = createdAt
        self.text = text
        self.mood = mood
    }
}

// 心情：0 表示未设置
enum Mood {
    static let emojis = ["", "😣", "😕", "😐", "🙂", "😄"]
    static func emoji(_ m: Int) -> String {
        (1...5).contains(m) ? emojis[m] : ""
    }
}
