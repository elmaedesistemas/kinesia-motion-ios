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

var results: [ValidationResult] = []
for (index, trial) in trials.enumerated() {
    let videoURL = folder.appendingPathComponent(trial.video)
    let label = "[\(index + 1)/\(trials.count)] \(trial.video)"

    guard FileManager.default.fileExists(atPath: videoURL.path) else {
        print("\(label): no encontré el archivo")
        results.append(ValidationResult(trial: trial, kinesia: nil, measuredFrames: 0))
        continue
    }

    do {
        let poses = try await VideoPoseProvider(url: videoURL, mirrored: trial.mirrored).readAll()
        if let peak = Validation.peakAngle(in: poses, exercise: trial.exercise, side: trial.side) {
            let difference = peak.angle - trial.goniometer
            print("\(label): goniómetro \(Int(trial.goniometer))° · Kinesia \(String(format: "%.1f", peak.angle))° · diferencia \(String(format: "%+.1f", difference))°")
            results.append(ValidationResult(trial: trial, kinesia: peak.angle, measuredFrames: peak.frames))
        } else {
            print("\(label): no se vieron las articulaciones en \(poses.count) cuadros. ¿Cuerpo completo y de perfil?")
            results.append(ValidationResult(trial: trial, kinesia: nil, measuredFrames: 0))
        }
    } catch {
        print("\(label): no pude leer el video (\(error))")
        results.append(ValidationResult(trial: trial, kinesia: nil, measuredFrames: 0))
    }
}

print("")
print(Validation.report(Validation.summarize(results)))

let output = folder.appendingPathComponent("resultados.csv")
do {
    try Validation.resultsCSV(results).write(to: output, atomically: true, encoding: .utf8)
    print("\nDetalle por medición: \(output.path)")
} catch {
    print("\nNo pude escribir \(output.path): \(error)")
}
