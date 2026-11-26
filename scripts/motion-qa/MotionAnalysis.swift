import Foundation

let args = CommandLine.arguments

guard args.count == 10 else {
    fputs(
        "usage: MotionAnalysis <raw-gray> <frames-tsv> <verdict>"
            + " <label> <theme> <fps> <threshold> <width> <height>\n",
        stderr
    )
    exit(2)
}

let rawPath = args[1]
let framesPath = args[2]
let verdictPath = args[3]
let label = args[4]
let theme = args[5]
let fps = Double(args[6]) ?? 60
let threshold = Int(args[7]) ?? 120
let width = Int(args[8]) ?? 340
let height = Int(args[9]) ?? 510
let frameSize = width * height

struct Metric {
    let index: Int
    let count: Int
    let xMin: Int
    let xMax: Int
    let yMin: Int
    let yMax: Int
    let cx: Double
    let cy: Double

    var pixelWidth: Int {
        count > 0 ? xMax - xMin + 1 : 0
    }
}

let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: rawPath), options: .mappedIfSafe)
} catch {
    fputs("cannot read raw frames: \(error)\n", stderr)
    exit(1)
}

let frameCount = data.count / frameSize
guard frameCount > 0, data.count % frameSize == 0 else {
    fputs("raw frame size mismatch\n", stderr)
    exit(1)
}

let xRange = 90..<250
let yRange = 210..<248
var metrics: [Metric] = []
metrics.reserveCapacity(frameCount)

data.withUnsafeBytes { rawBuffer in
    let bytes = rawBuffer.bindMemory(to: UInt8.self)
    for frame in 0..<frameCount {
        let base = frame * frameSize
        var count = 0
        var xMin = Int.max
        var xMax = Int.min
        var yMin = Int.max
        var yMax = Int.min
        var sumX = 0
        var sumY = 0

        for y in yRange {
            let row = base + y * width
            for x in xRange {
                let value = Int(bytes[row + x])
                let isInk = theme == "light" ? value < threshold : value > threshold
                guard isInk else { continue }
                count += 1
                xMin = min(xMin, x)
                xMax = max(xMax, x)
                yMin = min(yMin, y)
                yMax = max(yMax, y)
                sumX += x
                sumY += y
            }
        }

        if count > 0 {
            metrics.append(
                Metric(
                    index: frame,
                    count: count,
                    xMin: xMin,
                    xMax: xMax,
                    yMin: yMin,
                    yMax: yMax,
                    cx: Double(sumX) / Double(count),
                    cy: Double(sumY) / Double(count)
                )
            )
        } else {
            metrics.append(
                Metric(
                    index: frame,
                    count: 0,
                    xMin: 0,
                    xMax: 0,
                    yMin: 0,
                    yMax: 0,
                    cx: 0,
                    cy: 0
                )
            )
        }
    }
}

var tsv = "frame\tcount\txmin\txmax\tymin\tymax\tcx\tcy\n"
for metric in metrics {
    tsv += String(
        format: "%d\t%d\t%d\t%d\t%d\t%d\t%.3f\t%.3f\n",
        metric.index,
        metric.count,
        metric.xMin,
        metric.xMax,
        metric.yMin,
        metric.yMax,
        metric.cx,
        metric.cy
    )
}
do {
    try tsv.write(toFile: framesPath, atomically: true, encoding: .utf8)
} catch {
    fputs("cannot write frame metrics: \(error)\n", stderr)
    exit(1)
}

let baselineCount = min(60, max(1, frameCount / 4))
let baseline = metrics.prefix(baselineCount).filter { $0.count > 0 }
guard !baseline.isEmpty else {
    fputs("no baseline ink found\n", stderr)
    exit(1)
}

let baselineCX = baseline.map(\.cx).reduce(0, +) / Double(baseline.count)
let baselineWidth = baseline.map { Double($0.pixelWidth) }.reduce(0, +) / Double(baseline.count)
let baselineYMin = baseline.map(\.yMin).sorted()[baseline.count / 2]
let baselineYMax = baseline.map(\.yMax).sorted()[baseline.count / 2]

func differs(_ metric: Metric) -> Bool {
    if metric.count == 0 { return true }
    if abs(metric.cx - baselineCX) > 0.35 { return true }
    return Double(metric.pixelWidth) > baselineWidth * 1.35
}

let searchUpperBound = max(baselineCount, frameCount - 5)
let deviationIndices = (baselineCount..<searchUpperBound).filter { differs(metrics[$0]) }
let reasons: [String]
var transitionStart = -1
var transitionEnd = -1
var blankFrames = 0
var yMinVariation = 0
var yMaxVariation = 0
var endCenterDelta = Double.infinity
var maxWidthRatio = Double.infinity
var durationMS = 0.0
var direction = "unknown"

if deviationIndices.isEmpty {
    reasons = ["no transition frames detected"]
} else {
    transitionStart = deviationIndices.first!
    transitionEnd = deviationIndices.last!
    let expectedCount = transitionEnd - transitionStart + 1
    let transitionFrames = Array(metrics[transitionStart...transitionEnd])
    let nonBlank = transitionFrames.filter { $0.count > 0 }
    blankFrames = transitionFrames.filter { $0.count == 0 }.count
    let yMins = Set((baseline + nonBlank).map(\.yMin))
    let yMaxs = Set((baseline + nonBlank).map(\.yMax))
    yMinVariation = (yMins.max() ?? 0) - (yMins.min() ?? 0)
    yMaxVariation = (yMaxs.max() ?? 0) - (yMaxs.min() ?? 0)
    maxWidthRatio = (nonBlank.map { Double($0.pixelWidth) }.max() ?? 0) / baselineWidth
    let trailing = metrics.suffix(min(30, frameCount))
    let trailingInk = trailing.filter { $0.count > 0 }
    if !trailingInk.isEmpty {
        let endCX = trailingInk.map(\.cx).reduce(0, +) / Double(trailingInk.count)
        endCenterDelta = abs(endCX - baselineCX)
    }
    durationMS = Double(expectedCount) / fps * 1_000

    if let firstBlank = transitionFrames.firstIndex(where: { $0.count == 0 }),
       let lastBlank = transitionFrames.lastIndex(where: { $0.count == 0 })
    {
        let before = transitionFrames[..<firstBlank].filter { $0.count > 0 }
        let after = transitionFrames[(lastBlank + 1)...].filter { $0.count > 0 }
        let oldLeft = (before.map(\.cx).min() ?? baselineCX) < baselineCX - 1
        let newRight = (after.map(\.cx).max() ?? baselineCX) > baselineCX + 1
        direction = oldLeft && newRight ? "old-left/new-right" : "unexpected"
    }

    var failureReasons: [String] = []
    if deviationIndices.count != expectedCount {
        failureReasons.append("transition is not one contiguous cluster")
    }
    if !(17...26).contains(expectedCount) {
        failureReasons.append("transition frame count \(expectedCount) outside 17...26")
    }
    if !(280...450).contains(durationMS) {
        failureReasons.append(String(format: "duration %.1fms outside 280...450ms", durationMS))
    }
    if !(1...4).contains(blankFrames) {
        failureReasons.append("blank frames \(blankFrames) outside 1...4")
    }
    if yMinVariation > 1 || yMaxVariation > 1 {
        failureReasons.append("vertical bbox moved")
    }
    if endCenterDelta > 0.75 {
        failureReasons.append(String(format: "end center delta %.3f > 0.75", endCenterDelta))
    }
    if maxWidthRatio > 1.35 {
        failureReasons.append(String(format: "max width ratio %.3f > 1.35", maxWidthRatio))
    }
    if direction != "old-left/new-right" {
        failureReasons.append("Next direction is not old-left/new-right")
    }
    if metrics.suffix(15).allSatisfy({ $0.count == 0 }) {
        failureReasons.append("no settled readout after transition")
    }
    reasons = failureReasons
}

let status = reasons.isEmpty ? "PASS" : "FAIL"
let summary = String(
    format: "%@\t%@\t%@\t%d\t%.3f\t%d\t%d\t%.1f\t%d\t%d\t%d\t%.3f\t%.3f\t%@\n",
    status,
    label,
    theme,
    frameCount,
    fps,
    transitionStart,
    transitionEnd,
    durationMS,
    blankFrames,
    yMinVariation,
    yMaxVariation,
    endCenterDelta,
    maxWidthRatio,
    direction
)

let verdict = """
STATUS=\(status)
label=\(label)
theme=\(theme)
frames=\(frameCount)
fps=\(fps)
baseline_readout_y=\(baselineYMin)...\(baselineYMax)
transition_start=\(transitionStart)
transition_end=\(transitionEnd)
duration_ms=\(durationMS)
blank_frames=\(blankFrames)
y_min_variation=\(yMinVariation)
y_max_variation=\(yMaxVariation)
end_center_delta=\(endCenterDelta)
max_width_ratio=\(maxWidthRatio)
direction=\(direction)
reasons=\(reasons.isEmpty ? "none" : reasons.joined(separator: "; "))
"""

do {
    try verdict.write(toFile: verdictPath, atomically: true, encoding: .utf8)
} catch {
    fputs("cannot write verdict: \(error)\n", stderr)
    exit(1)
}

print(summary, terminator: "")
exit(status == "PASS" ? 0 : 1)
