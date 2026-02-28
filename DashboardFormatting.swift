import Foundation

extension Int {
    var grouped: String {
        NumberFormatter.grouped.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    var leaf: String {
        NumberFormatter.leaf.string(from: NSNumber(value: self)).map { "\($0) ☘️" } ?? String(format: "%.2f ☘️", self)
    }

    var leafFull: String {
        NumberFormatter.leafFull.string(from: NSNumber(value: self)).map { "\($0) ☘️" } ?? String(format: "%.8f ☘️", self)
    }

    var leafPrecise: String {
        NumberFormatter.leafPrecise.string(from: NSNumber(value: self)).map { "\($0) ☘️" } ?? String(format: "%.4f ☘️", self)
    }

    var usd: String {
        leaf
    }

    var usdFull: String {
        leafFull
    }

    var usdPrecise: String {
        leafPrecise
    }

    var durationText: String {
        let totalMinutes = Int(self.rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

extension Date {
    var shortDate: String {
        DateFormatter.shortDate.string(from: self)
    }

    var dateTimeText: String {
        DateFormatter.shortDateTime.string(from: self)
    }

    var activityTimestampText: String {
        DateFormatter.activityTimestamp.string(from: self)
    }
}

extension Int {
    var hourText: String {
        String(format: "%02d:00", self)
    }

    var compactGrouped: String {
        formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}

extension String {
    var dayLabel: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: self) else { return self }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

private extension NumberFormatter {
    static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let leaf: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static let leafPrecise: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static let leafFull: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        formatter.usesGroupingSeparator = true
        return formatter
    }()
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let activityTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

extension Date {
    var monthDayText: String {
        DateFormatter.monthDay.string(from: self)
    }
}
