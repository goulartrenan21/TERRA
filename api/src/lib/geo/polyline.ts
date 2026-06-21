export type Point = [number, number] // [lng, lat]

// ─── Douglas-Peucker simplification ─────────────────────────────────────────

function perpendicularDistance(point: Point, lineStart: Point, lineEnd: Point): number {
  const [px, py] = point
  const [x1, y1] = lineStart
  const [x2, y2] = lineEnd

  const dx = x2 - x1
  const dy = y2 - y1

  if (dx === 0 && dy === 0) {
    return Math.sqrt((px - x1) ** 2 + (py - y1) ** 2)
  }

  const t = ((px - x1) * dx + (py - y1) * dy) / (dx ** 2 + dy ** 2)
  const nearestX = x1 + t * dx
  const nearestY = y1 + t * dy
  return Math.sqrt((px - nearestX) ** 2 + (py - nearestY) ** 2)
}

export function douglasPeucker(points: Point[], epsilon: number): Point[] {
  if (points.length <= 2) return points

  let maxDist = 0
  let maxIdx  = 0

  for (let i = 1; i < points.length - 1; i++) {
    const d = perpendicularDistance(points[i], points[0], points[points.length - 1])
    if (d > maxDist) { maxDist = d; maxIdx = i }
  }

  if (maxDist > epsilon) {
    const left  = douglasPeucker(points.slice(0, maxIdx + 1), epsilon)
    const right = douglasPeucker(points.slice(maxIdx), epsilon)
    return [...left.slice(0, -1), ...right]
  }

  return [points[0], points[points.length - 1]]
}

// ─── Outlier removal ─────────────────────────────────────────────────────────

// Earth radius in meters
const R = 6_371_000

function haversineMeters(a: Point, b: Point): number {
  const dLat = ((b[1] - a[1]) * Math.PI) / 180
  const dLng = ((b[0] - a[0]) * Math.PI) / 180
  const lat1 = (a[1] * Math.PI) / 180
  const lat2 = (b[1] * Math.PI) / 180
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(h))
}

// Samples are 3s apart — max 55 km/h ≈ 15.3 m/s → 46m per interval
const MAX_DISTANCE_PER_SAMPLE_M = 50

export function removeOutliers(points: Point[]): Point[] {
  if (points.length < 2) return points
  const result: Point[] = [points[0]]
  for (let i = 1; i < points.length; i++) {
    const dist = haversineMeters(result[result.length - 1], points[i])
    if (dist <= MAX_DISTANCE_PER_SAMPLE_M) {
      result.push(points[i])
    }
  }
  return result
}

// ─── Clean polyline (remove outliers + simplify) ─────────────────────────────

// ~11m in degrees at equator
const DP_EPSILON = 0.0001

export function cleanPolyline(points: Point[]): Point[] {
  const withoutOutliers = removeOutliers(points)
  return douglasPeucker(withoutOutliers, DP_EPSILON)
}
