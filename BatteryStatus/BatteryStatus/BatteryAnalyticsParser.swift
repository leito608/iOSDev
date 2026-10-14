import Foundation

/// Battery values extracted from an iOS analytics file
/// (Analytics-YYYY-MM-DD-xxxxxx.ips.ca.synced).
struct BatteryInfo {
    // File header
    var osVersion: String?
    var reportTimestamp: String?

    // Battery health
    var cycleCount: Int?
    var maxCapacityPercent: Int?      // matches "Maximum Capacity" in Settings
    var nominalChargeCapacity: Int?   // probably mAh
    var rawMaxCapacity: Int?          // probably mAh
    var maxFCC: Int?                  // full charge capacity, probably mAh
    var minFCC: Int?

    // Daily readings
    var averageTemperature: Int?      // probably degrees C
    var dailyMaxSoc: Int?             // highest charge % today
    var dailyMinSoc: Int?             // lowest charge % today
    var maxPackVoltage: Int?          // probably mV
    var minPackVoltage: Int?
    var lastUpdate: Date?

    // Time spent at high charge, bins 0...9 (unit not documented by Apple)
    var timeAtHighSoc: [Int] = []
}

enum BatteryParser {

    /// The file is "newline-delimited JSON": every line is its own JSON object.
    /// Line 1 = header, line 2 = metadata, the rest = analytics events.
    static func parse(_ text: String) -> BatteryInfo? {
        var info = BatteryInfo()
        var foundBatteryRecord = false
        var highSoc: [Int: Int] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }   // skip any line that is not valid JSON

            // Header line
            if let os = obj["os_version"] as? String {
                info.osVersion = os
                info.reportTimestamp = obj["timestamp"] as? String
                continue
            }

            guard let name = obj["name"] as? String,
                  let msg = obj["message"] as? [String: Any]
            else { continue }

            switch name {

            case "BatteryConfigValueHistogramFinal_V2":
                // The file contains this event twice (BatteryPackID 0 and 255)
                // with identical values, so we only read the first one.
                if foundBatteryRecord { break }
                foundBatteryRecord = true

                info.cycleCount            = msg["last_value_CycleCount"] as? Int
                info.maxCapacityPercent    = msg["last_value_MaximumCapacityPercent"] as? Int
                info.nominalChargeCapacity = msg["last_value_NominalChargeCapacity"] as? Int
                info.rawMaxCapacity        = msg["last_value_AppleRawMaxCapacity"] as? Int
                info.maxFCC                = msg["last_value_MaximumFCC"] as? Int
                info.minFCC                = msg["last_value_MinimumFCC"] as? Int
                info.averageTemperature    = msg["last_value_AverageTemperature"] as? Int
                info.dailyMaxSoc           = msg["last_value_DailyMaxSoc"] as? Int
                info.dailyMinSoc           = msg["last_value_DailyMinSoc"] as? Int
                info.maxPackVoltage        = msg["last_value_MaximumPackVoltage"] as? Int
                info.minPackVoltage        = msg["last_value_MinimumPackVoltage"] as? Int
                if let t = msg["last_value_UpdateTime"] as? Double {
                    info.lastUpdate = Date(timeIntervalSince1970: t)
                }

            case "BatteryTimeAtHighSocLast":
                // One line per bin: {"bin":"3","last_value_value":15}
                if let binString = msg["bin"] as? String,
                   let bin = Int(binString),
                   let value = msg["last_value_value"] as? Int {
                    highSoc[bin] = value
                }

            default:
                break
            }
        }

        info.timeAtHighSoc = highSoc.keys.sorted().map { highSoc[$0] ?? 0 }
        return foundBatteryRecord ? info : nil
    }
}
