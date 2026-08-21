import Foundation

// MARK: - Modelo de resultado

struct CSVAnalysis {
    let totalPoints: Int
    let meanDepth: Float
    let minDepth: Float
    let maxDepth: Float
    let stdDepth: Float
    let highConfidence: Int
    let mediumConfidence: Int
    let lowConfidence: Int

    var highPct: Double { totalPoints > 0 ? Double(highConfidence) / Double(totalPoints) * 100 : 0 }
    var mediumPct: Double { totalPoints > 0 ? Double(mediumConfidence) / Double(totalPoints) * 100 : 0 }
    var lowPct: Double { totalPoints > 0 ? Double(lowConfidence) / Double(totalPoints) * 100 : 0 }
}

// MARK: - Ficheiro guardado

struct SavedCapture: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }
}

// MARK: - Fonte de dados da aba Análise

enum AnalysisSource: Hashable {
    case live
    case file(SavedCapture)
}

// MARK: - Erros

enum CSVAnalyzerError: Error {
    case noData
}

// MARK: - Listagem de CSVs guardados

// Lista os CSVs da pasta Documents, do mais recente para o mais antigo.
// Ajusta o diretório se a tua app guardar as capturas noutro local.
func listSavedCSVs() -> [SavedCapture] {
    let fm = FileManager.default
    guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
    let files = (try? fm.contentsOfDirectory(
        at: docs,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    )) ?? []

    return files
        .filter { $0.pathExtension.lowercased() == "csv" }
        .sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        .map { SavedCapture(url: $0) }
}

// MARK: - Parser / estatísticas descritivas

// Lê o CSV em streaming (sem guardar todos os pontos) e calcula estatísticas.
// Deteta a coluna de profundidade por nome ("depth" ou "depth_m") e a de
// confiança ("confidence"); se não houver cabeçalho, usa as posições por omissão.
func analyzeCSV(at url: URL) throws -> CSVAnalysis {
    let content = try String(contentsOf: url, encoding: .utf8)

    // Ordem por omissão: timestamp, x, y, depth_m, confidence, world_x, world_y, world_z
    var depthIdx = 3
    var confIdx = 4
    var headerHandled = false

    var count = 0
    var sum = 0.0
    var sumSq = 0.0
    var minD = Float.greatestFiniteMagnitude
    var maxD = -Float.greatestFiniteMagnitude
    var high = 0, medium = 0, low = 0

    content.enumerateLines { line, _ in
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard !trimmedLine.isEmpty else { return }

        let cols = trimmedLine.split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        // Primeira linha: decidir se é cabeçalho
        if !headerHandled {
            headerHandled = true
            let isHeader = cols.contains { Double($0) == nil }
            if isHeader {
                let lower = cols.map { $0.lowercased() }
                if let i = lower.firstIndex(where: { $0 == "depth" || $0 == "depth_m" }) { depthIdx = i }
                if let i = lower.firstIndex(where: { $0 == "confidence" }) { confIdx = i }
                return // saltar a linha de cabeçalho
            }
            // sem cabeçalho: continua e processa esta linha como dados
        }

        guard cols.count > depthIdx, let depth = Float(cols[depthIdx]) else { return }
        count += 1
        let d = Double(depth)
        sum += d
        sumSq += d * d
        if depth < minD { minD = depth }
        if depth > maxD { maxD = depth }

        if cols.count > confIdx, let c = Int(cols[confIdx]) {
            switch c {
            case 2: high += 1
            case 1: medium += 1
            default: low += 1
            }
        }
    }

    guard count > 0 else { throw CSVAnalyzerError.noData }

    let mean = sum / Double(count)
    let variance = max(0, sumSq / Double(count) - mean * mean)

    return CSVAnalysis(
        totalPoints: count,
        meanDepth: Float(mean),
        minDepth: minD,
        maxDepth: maxD,
        stdDepth: Float(variance.squareRoot()),
        highConfidence: high,
        mediumConfidence: medium,
        lowConfidence: low
    )
}
