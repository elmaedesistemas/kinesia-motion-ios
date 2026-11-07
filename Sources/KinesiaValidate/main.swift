//
//  main.swift
//  KinesiaMotion
//
//  Created by Deivy Mejia Ruiz on 24/10/26.
//
//  Compares Kinesia's angles with a goniometer.
//
//      swift run kinesia-validate path/to/mediciones.csv
//
//  Videos are looked up next to the CSV. Writes resultados.csv in the same folder.
//

import Foundation
import KinesiaMotion
import KinesiaMotionVision
import KinesiaValidation

let arguments = CommandLine.arguments.dropFirst()
guard let csvPath = arguments.first else {
    print("""
    Uso: swift run kinesia-validate mediciones.csv

    El CSV lleva una línea por medición:
        video,ejercicio,lado,goniometro,espejo
        codo-01.mov,codo,derecho,132,no

    Ejercicios: \(["codo", "rodilla", "hombro-flexion", "hombro-abduccion", "cadera-flexion", "cadera-abduccion", "tobillo", "cuello"].joined(separator: ", "))
    """)
    exit(1)
}

let csvURL = URL(fileURLWithPath: csvPath)
let folder = csvURL.deletingLastPathComponent()

let trials: [ValidationTrial]
do {
    trials = try Validation.parseTrials(csv: String(contentsOf: csvURL, encoding: .utf8))
} catch {
    print("No pude leer \(csvURL.lastPathComponent): \(error)")
    exit(1)
}
guard !trials.isEmpty else {
    print("El CSV no tiene mediciones.")
    exit(1)
}

print("Analizando \(trials.count) video(s)…\n")

var results: [MeasureSpace: [ValidationResult]] = [.image: [], .world: []]
func record(_ trial: ValidationTrial,
            _ peaks: [MeasureSpace: (angle: Double, frames: Int)] = [:],
            into results: inout [MeasureSpace: [ValidationResult]]) {
    for space in MeasureSpace.allCases {
        results[space, default: []].append(
            ValidationResult(trial: trial, kinesia: peaks[space]?.angle, measuredFrames: peaks[space]?.frames ?? 0))
    }
}
func describe(_ peak: (angle: Double, frames: Int)?, _ goniometer: Double) -> String {
    guard let peak else { return "–" }
    return "\(String(format: "%.1f", peak.angle))° (\(String(format: "%+.1f", peak.angle - goniometer))°)"
}

for (index, trial) in trials.enumerated() {
    let videoURL = folder.appendingPathComponent(trial.video)
    let label = "[\(index + 1)/\(trials.count)] \(trial.video)"

    guard FileManager.default.fileExists(atPath: videoURL.path) else {
        print("\(label): no encontré el archivo")
        record(trial, into: &results)
        continue
    }

    do {
        // One pass gives both: the 2D points and the 3D ones.
        let poses = try await VideoPoseProvider(url: videoURL, mirrored: trial.mirrored, world: true).readAll()
        var peaks: [MeasureSpace: (angle: Double, frames: Int)] = [:]
        for space in MeasureSpace.allCases {
            peaks[space] = Validation.peakAngle(in: poses, exercise: trial.exercise, side: trial.side, space: space)
        }
        if peaks.isEmpty {
            print("\(label): no se vieron las articulaciones en \(poses.count) cuadros. ¿Cuerpo completo y de perfil?")
        } else {
            print("\(label): goniómetro \(Int(trial.goniometer))° · 2D \(describe(peaks[.image], trial.goniometer)) · 3D \(describe(peaks[.world], trial.goniometer))")
        }
        record(trial, peaks, into: &results)
    } catch {
        print("\(label): no pude leer el video (\(error))")
        record(trial, into: &results)
    }
}

let outputs: [(MeasureSpace, String, String)] = [
    (.image, "2D · sobre la imagen", "resultados.csv"),
    (.world, "3D · con profundidad", "resultados-3d.csv"),
]
for (space, title, file) in outputs {
    print("\n\(title)\n")
    print(Validation.report(Validation.summarize(results[space] ?? [])))

    let output = folder.appendingPathComponent(file)
    do {
        try Validation.resultsCSV(results[space] ?? []).write(to: output, atomically: true, encoding: .utf8)
        print("\nDetalle por medición: \(output.path)")
    } catch {
        print("\nNo pude escribir \(output.path): \(error)")
    }
}
