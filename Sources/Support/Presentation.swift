import Foundation
import SwiftUI

struct TimerText: View {
    let start: Date
    @State private var now = Date()

    var body: some View {
        Text(format(Int(now.timeIntervalSince(start))))
            .font(.title2.monospacedDigit())
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) {
                now = $0
            }
    }
}

func format(_ seconds: Int) -> String {
    String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
}

func hours(_ entries: [TimeEntry]) -> String {
    String(format: "%.2f h", Double(entries.reduce(0) { $0 + $1.seconds }) / 3600)
}

func csvField(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
