//
//  Validation.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 24/10/26.
//

import Foundation
import KinesiaMotion

/// One measurement: a video of the patient at the end of the range, and what the goniometer read.
public struct ValidationTrial: Sendable, Equatable {
    public let video: String
    public let exercise: ExerciseDefinition
    public let side: BodySide
    public let goniometer: Double
    /// The video shows the patient as a mirror does (selfie that kept the flip).
    public let mirrored: Bool

    public init(video: String, exercise: ExerciseDefinition, side: BodySide, goniometer: Double, mirrored: Bool = false) {
        self.video = video
        self.exercise = exercise
        self.side = side
        self.goniometer = goniometer
        self.mirrored = mirrored
    }
}

public struct ValidationResult: Sendable {
    public let trial: ValidationTrial
    /// What Kinesia measured; nil when the joints were never visible.
    public let kinesia: Double?
    /// Frames where the angle could be measured.
    public let measuredFrames: Int

    public var error: Double? { kinesia.map { $0 - trial.goniometer } }

    public init(trial: ValidationTrial, kinesia: Double?, measuredFrames: Int) {
        self.trial = trial
        self.kinesia = kinesia
        self.measuredFrames = measuredFrames
    }
}

/// The summary for one exercise and side.
public struct ValidationSummary: Sendable {
    public let exercise: ExerciseDefinition
    public let side: BodySide
    public let trials: Int
    public let failedTrials: Int
    /// Mean of (Kinesia − goniometer): positive means Kinesia reads high.
    public let bias: Double?
    /// Mean absolute error, the number compared with the ±5° goal.
    public let meanAbsoluteError: Double?
    public let maxAbsoluteError: Double?
    /// Share of trials within ±5°, 0...1.
    public let withinTolerance: Double?

    public static let tolerance: Double = 5

    public var passes: Bool { (meanAbsoluteError ?? .infinity) <= Self.tolerance }
}

public enum Validation {
    public enum CSVError: Error, Equatable, CustomStringConvertible {
        case missingColumn(String)
        case badRow(line: Int, reason: String)

        public var description: String {
            switch self {
            case .missingColumn(let name): "Falta la columna «\(name)» en la primera línea."
            case .badRow(let line, let reason): "Línea \(line): \(reason)"
            }
        }
    }

    /// Names the student can write in the CSV, besides the library ids.
    static let aliases: [String: String] = [
        "codo": "elbow.flexion",
        "rodilla": "knee.flexion.standing",
        "hombro-flexion": "shoulder.flexion",
        "hombro-abduccion": "shoulder.abduction",
        "cadera-flexion": "hip.flexion.standing",
        "cadera-abduccion": "hip.abduction.standing",
        "tobillo": "ankle.dorsiflexion.lunge",
        "cuello": "neck.lateralFlexion",
    ]

    /// Reads `video,ejercicio,lado,goniometro[,espejo]` (Spanish headers; English ones work too).
    /// Lines starting with `#` and empty lines are skipped. Decimal commas are fine: `92,5` inside quotes or `92.5`.
    public static func parseTrials(csv: String) throws -> [ValidationTrial] {
        var lines = csv.split(whereSeparator: \.isNewline).map(String.init).enumerated().filter {
            let text = $0.element.trimmingCharacters(in: .whitespaces)
            return !text.isEmpty && !text.hasPrefix("#")
        }
        guard !lines.isEmpty else { return [] }

        let header = fields(lines.removeFirst().element).map { $0.lowercased() }
        func column(_ names: String...) throws -> Int {
            guard let index = header.firstIndex(where: { names.contains($0) }) else {
                throw CSVError.missingColumn(names[0])
            }
            return index
        }
        let videoColumn = try column("video")
        let exerciseColumn = try column("ejercicio", "exercise")
        let sideColumn = try column("lado", "side")
        let goniometerColumn = try column("goniometro", "goniómetro", "goniometer")
        let mirroredColumn = header.firstIndex { ["espejo", "mirrored"].contains($0) }

        return try lines.map { offset, line in
            let row = fields(line)
            let number = offset + 1
            func value(_ index: Int) -> String { index < row.count ? row[index] : "" }

            let video = value(videoColumn)
            guard !video.isEmpty else { throw CSVError.badRow(line: number, reason: "falta el video") }

            let rawExercise = value(exerciseColumn).lowercased()
            guard let exercise = ExerciseLibrary.definition(id: aliases[rawExercise] ?? rawExercise)
                    ?? ExerciseLibrary.all.first(where: { $0.id.lowercased() == rawExercise }) else {
                throw CSVError.badRow(line: number, reason: "ejercicio desconocido «\(value(exerciseColumn))»")
            }

            let side: BodySide
            switch value(sideColumn).lowercased() {
            case "izquierdo", "izquierda", "izq", "left", "l": side = .left
            case "derecho", "derecha", "der", "right", "r": side = .right
            default: throw CSVError.badRow(line: number, reason: "lado «\(value(sideColumn))»: usa izquierdo o derecho")
            }

            guard let degrees = Double(value(goniometerColumn).replacingOccurrences(of: ",", with: ".")) else {
                throw CSVError.badRow(line: number, reason: "goniómetro «\(value(goniometerColumn))» no es un número")
            }

            let mirrored = mirroredColumn.map { ["si", "sí", "yes", "true", "1"].contains(value($0).lowercased()) } ?? false
            return ValidationTrial(video: video, exercise: exercise, side: side, goniometer: degrees, mirrored: mirrored)
        }
    }

    /// Splits one CSV line; commas inside double quotes stay in the field.
    static func fields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var quoted = false
        for character in line {
            switch character {
            case "\"": quoted.toggle()
            case "," where !quoted, ";" where !quoted:
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            default: current.append(character)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    /// The angle at the end of the range: the median of the 5 highest frames, so one bad
    /// detection can't set the result. nil when the joints were never measured.
    public static func peakAngle(in poses: [Pose], exercise: ExerciseDefinition, side: BodySide) -> (angle: Double, frames: Int)? {
        let values = poses.compactMap { exercise.primary.value(in: $0, side: side) }
        guard !values.isEmpty else { return nil }
        let top = values.sorted(by: >).prefix(5).sorted()
        let middle = top.count / 2
        let median = top.count.isMultiple(of: 2) ? (top[middle - 1] + top[middle]) / 2 : top[middle]
        return (median, values.count)
    }

    /// One summary per exercise and side, in the order they first appear.
    public static func summarize(_ results: [ValidationResult]) -> [ValidationSummary] {
        var order: [String] = []
        var groups: [String: [ValidationResult]] = [:]
        for result in results {
            let key = "\(result.trial.exercise.id)|\(result.trial.side.rawValue)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(result)
        }
        return order.compactMap { key in
            guard let group = groups[key], let first = group.first else { return nil }
            let errors = group.compactMap(\.error)
            let absolute = errors.map(abs)
            func mean(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
            return ValidationSummary(
                exercise: first.trial.exercise,
                side: first.trial.side,
                trials: group.count,
                failedTrials: group.count - errors.count,
                bias: mean(errors),
                meanAbsoluteError: mean(absolute),
                maxAbsoluteError: absolute.max(),
                withinTolerance: absolute.isEmpty ? nil
                    : Double(absolute.filter { $0 <= ValidationSummary.tolerance }.count) / Double(absolute.count)
            )
        }
    }

    // MARK: - Output

    /// Per-trial results as CSV, to open in Excel or Numbers.
    public static func resultsCSV(_ results: [ValidationResult]) -> String {
        var lines = ["video,ejercicio,lado,goniometro,kinesia,diferencia,cuadros_medidos"]
        for r in results {
            lines.append([
                r.trial.video,
                r.trial.exercise.id,
                r.trial.side == .left ? "izquierdo" : "derecho",
                format(r.trial.goniometer),
                r.kinesia.map(format) ?? "",
                r.error.map(format) ?? "",
                "\(r.measuredFrames)",
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The summary as a readable table for the terminal.
    public static func report(_ summaries: [ValidationSummary]) -> String {
        var lines = [
            "Ejercicio                 Lado  Pruebas  Error medio  Sesgo   Máx    ±5°    Resultado",
            String(repeating: "─", count: 86),
        ]
        for s in summaries {
            let side = s.side == .left ? "izq" : "der"
            let trials = s.failedTrials > 0 ? "\(s.trials - s.failedTrials)/\(s.trials)" : "\(s.trials)"
            let result = s.meanAbsoluteError == nil ? "sin datos" : (s.passes ? "✅ pasa" : "❌ no pasa")
            lines.append([
                s.exercise.id.padding(toLength: 26, withPad: " ", startingAt: 0),
                side.padding(toLength: 6, withPad: " ", startingAt: 0),
                trials.padding(toLength: 9, withPad: " ", startingAt: 0),
                (s.meanAbsoluteError.map { format($0) + "°" } ?? "–").padding(toLength: 13, withPad: " ", startingAt: 0),
                (s.bias.map { signed($0) + "°" } ?? "–").padding(toLength: 8, withPad: " ", startingAt: 0),
                (s.maxAbsoluteError.map { format($0) + "°" } ?? "–").padding(toLength: 7, withPad: " ", startingAt: 0),
                (s.withinTolerance.map { "\(Int(($0 * 100).rounded()))%" } ?? "–").padding(toLength: 7, withPad: " ", startingAt: 0),
                result,
            ].joined())
        }
        lines.append("")
        lines.append("Pasa si el error medio es de ±\(Int(ValidationSummary.tolerance))° o menos. Sesgo positivo: Kinesia mide de más.")
        return lines.joined(separator: "\n")
    }

    static func format(_ value: Double) -> String { String(format: "%.1f", value) }
    static func signed(_ value: Double) -> String { (value >= 0 ? "+" : "") + format(value) }
}
