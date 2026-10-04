//
//  DailyForecastService.swift
//  Glyfica
//
//  Local deterministic fallback when generateReading(type: daily) is offline.
//

import Foundation

enum DailyForecastService {
    static func dateKey(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let y = parts.year ?? 0
        let m = parts.month ?? 0
        let d = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func forecast(
        for profile: BirthProfile,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> DailyForecast {
        let sign = profile.sign
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        func pick(_ salt: Int, count: Int) -> Int {
            abs(day * 31 + sign.sortIndex * 17 + salt * 13) % count
        }
        func score(_ salt: Int) -> Int {
            42 + abs(day * 19 + sign.sortIndex * 11 + salt * 7) % 54
        }

        let headlines = [
            "A clear ask wins today",
            "Keep the circle close",
            "One steady hour first",
            "Soft honesty travels far",
            "Choose the smaller yes",
            "Protect your first energy"
        ]
        let focuses = [
            "Say the thing you have been editing in your head.",
            "Protect the hour that is actually yours.",
            "Choose the smaller promise you can keep.",
            "Let a conversation finish before you decide.",
            "Move one stuck task before you open anything new.",
            "Notice who steadies you, and stay near them."
        ]
        let summaries = [
            "The day favors a clear ask over a perfect mood. \(sign.title) does better when the next step is named out loud.\n\nLeave room after important talks — your best read of people arrives a little late.",
            "Something familiar asks for a second look. Do not rush the rewrite — adjust the part that has been bothering you.\n\nA short walk or quiet reset will make the evening easier to trust.",
            "Energy is uneven. Put the important conversation before the errands, while you still mean what you say.\n\nKeep tonight simple; the day already asked enough of you.",
            "A small social plan carries more luck than a big one. Keep the circle tight and the plan simple.\n\nIf someone softens toward you, meet them halfway without over-explaining.",
            "You may want a clean answer by evening. Take the useful one instead, and leave the rest for tomorrow.\n\nYour sign does well when progress is visible, even if it is small.",
            "Old habits pull toward comfort. Give the new choice the first hour, then let the rest of the day be ordinary.\n\nTenderness with yourself counts as strategy today."
        ]
        let loveTips = [
            "A warm check-in matters more than a perfect speech.",
            "Name one need early, before distance does the talking.",
            "Stay curious about their mood instead of guessing it.",
            "Shared quiet can be as bonding as a plan."
        ]
        let workTips = [
            "Finish one real task before you open a new tab.",
            "Decide with a deadline, not with endless options.",
            "Ask for the missing detail instead of waiting for certainty.",
            "Protect a focused block and treat the rest as flexible."
        ]
        let dos = [
            "Send the message you have rewritten three times.",
            "Start with the task that would calm you if it were done.",
            "Take a short break before any sharp reply.",
            "Say yes to one small invitation that feels kind."
        ]
        let avoids = [
            "Do not force a big decision while you are hungry or rushed.",
            "Skip replaying an old argument in your head all afternoon.",
            "Avoid promising more than tonight can hold.",
            "Do not measure the whole day by one awkward moment."
        ]

        let focusHint = profile.concern?.title.lowercased()
        let summaryBase = summaries[pick(2, count: summaries.count)]
        let summary = focusHint.map { "With \($0) on your mind: " + summaryBase } ?? summaryBase

        return DailyForecast(
            date: date,
            dateKey: dateKey(for: date, calendar: calendar),
            sign: sign,
            headline: headlines[pick(0, count: headlines.count)],
            focus: focuses[pick(1, count: focuses.count)],
            summary: summary,
            loveTip: loveTips[pick(3, count: loveTips.count)],
            workTip: workTips[pick(4, count: workTips.count)],
            doToday: dos[pick(5, count: dos.count)],
            avoidToday: avoids[pick(6, count: avoids.count)],
            love: score(3),
            energy: score(4),
            mood: score(5),
            luck: score(6)
        )
    }
}
