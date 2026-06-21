import type { Point } from './polyline'

// ─── Segment intersection ────────────────────────────────────────────────────

function segmentsIntersect(
  p1: Point, p2: Point,
  p3: Point, p4: Point,
): Point | null {
  const [x1, y1] = p1
  const [x2, y2] = p2
  const [x3, y3] = p3
  const [x4, y4] = p4

  const denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
  if (Math.abs(denom) < 1e-10) return null // parallel

  const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
  const u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom

  // Strictly inside both segments (exclude endpoints to avoid detecting
  // shared vertices as intersections)
  if (t > 0.001 && t < 0.999 && u > 0.001 && u < 0.999) {
    return [x1 + t * (x2 - x1), y1 + t * (y2 - y1)]
  }
  return null
}

// ─── Loop detection ──────────────────────────────────────────────────────────

export interface DetectedLoop {
  polygon: Point[]        // closed ring
  startIdx: number        // index in original path where loop begins
  endIdx: number          // index where loop ends
  crossingPoint: Point    // where the path crossed itself
}

export function detectLoops(points: Point[]): DetectedLoop[] {
  const loops: DetectedLoop[] = []

  // For each segment i, check all non-adjacent segments j (j > i + 1)
  for (let i = 0; i < points.length - 1; i++) {
    for (let j = i + 2; j < points.length - 1; j++) {
      // Skip adjacent segments (share endpoint)
      if (j === i + 1) continue

      const crossing = segmentsIntersect(
        points[i], points[i + 1],
        points[j], points[j + 1],
      )

      if (crossing) {
        // Build closed polygon: crossing → points[i+1..j] → crossing
        const polygon: Point[] = [
          crossing,
          ...points.slice(i + 1, j + 1),
          crossing,
        ]

        loops.push({
          polygon,
          startIdx: i,
          endIdx: j + 1,
          crossingPoint: crossing,
        })

        // Skip past this loop to avoid detecting sub-loops of the same crossing
        i = j
        break
      }
    }
  }

  return loops
}

// ─── Loop validation ─────────────────────────────────────────────────────────

// Shoelace formula — returns signed area in square degrees
function polygonAreaDegrees(ring: Point[]): number {
  let area = 0
  const n = ring.length
  for (let i = 0; i < n; i++) {
    const [x1, y1] = ring[i]
    const [x2, y2] = ring[(i + 1) % n]
    area += x1 * y2 - x2 * y1
  }
  return Math.abs(area) / 2
}

// Rough conversion: 1 degree² ≈ (111_000m)² ≈ 12_321 km²
// We only need this to pre-filter before PostGIS computes the real geodesic area
const DEG2_TO_KM2 = 12_321

const MIN_AREA_KM2 = 0.01
const MAX_AREA_KM2 = 50

export function isValidLoop(polygon: Point[]): boolean {
  if (polygon.length < 4) return false

  const areaKm2 = polygonAreaDegrees(polygon) * DEG2_TO_KM2
  return areaKm2 >= MIN_AREA_KM2 && areaKm2 <= MAX_AREA_KM2
}
