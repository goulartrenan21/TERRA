import { describe, it, expect } from 'vitest'
import { cleanPolyline, removeOutliers, douglasPeucker, type Point } from '../lib/geo/polyline'
import { detectLoops, isValidLoop } from '../lib/geo/loops'
import { calculateXP, computeLevel } from '../services/capture.service'

// ─── cleanPolyline ────────────────────────────────────────────────────────────

describe('removeOutliers', () => {
  it('keeps points within 50m per sample', () => {
    const pts: Point[] = [
      [-46.6500, -23.5500],
      [-46.6496, -23.5500], // ~44m east — OK
      [-46.6490, -23.5500], // ~66m — outlier
    ]
    const result = removeOutliers(pts)
    expect(result).toHaveLength(2)
    expect(result[1]).toEqual(pts[1])
  })

  it('removes GPS teleport (200km/h spike)', () => {
    const pts: Point[] = [
      [-46.6500, -23.5500],
      [-46.0000, -23.5500], // ~60km jump — outlier
      [-46.6498, -23.5500], // back to normal
    ]
    const result = removeOutliers(pts)
    // second point removed, third is within 50m of first? no, it's within 50m of first
    expect(result).not.toContainEqual(pts[1])
  })

  it('returns single point unchanged', () => {
    const pts: Point[] = [[-46.65, -23.55]]
    expect(removeOutliers(pts)).toEqual(pts)
  })
})

describe('douglasPeucker', () => {
  it('removes collinear intermediate points', () => {
    const pts: Point[] = [
      [0, 0], [1, 0], [2, 0], [3, 0], [4, 0],
    ]
    const result = douglasPeucker(pts, 0.0001)
    expect(result).toHaveLength(2)
    expect(result[0]).toEqual([0, 0])
    expect(result[result.length - 1]).toEqual([4, 0])
  })

  it('keeps points that deviate significantly', () => {
    const pts: Point[] = [
      [0, 0], [1, 1], [2, 0],
    ]
    const result = douglasPeucker(pts, 0.0001)
    expect(result).toHaveLength(3)
  })
})

// ─── detectLoops ─────────────────────────────────────────────────────────────

describe('detectLoops', () => {
  it('detects a simple triangle loop', () => {
    // Path that crosses itself forming a triangle
    const pts: Point[] = [
      [0, 0],
      [2, 0],
      [1, 2],
      [1, -1], // crosses segment [0,0]-[2,0]
    ]
    const loops = detectLoops(pts)
    expect(loops.length).toBeGreaterThanOrEqual(1)
    expect(loops[0].crossingPoint).toBeDefined()
  })

  it('detects bowtie (2 loops sharing a crossing) as at least 1 loop', () => {
    // Bowtie: (0,0)→(4,4)→(4,0)→(0,4)→(0,0)
    // Segment (0,0)→(4,4) crosses segment (4,0)→(0,4) at (2,2)
    const pts: Point[] = [
      [0, 0],
      [4, 4],
      [4, 0],
      [0, 4],
      [0, 0],
    ]
    const loops = detectLoops(pts)
    expect(loops.length).toBeGreaterThanOrEqual(1)
    // Crossing point should be near (2,2)
    const cp = loops[0].crossingPoint
    expect(cp[0]).toBeCloseTo(2, 1)
    expect(cp[1]).toBeCloseTo(2, 1)
  })

  it('returns empty for a straight line', () => {
    const pts: Point[] = [[0, 0], [1, 0], [2, 0], [3, 0]]
    expect(detectLoops(pts)).toHaveLength(0)
  })
})

// ─── isValidLoop ─────────────────────────────────────────────────────────────

describe('isValidLoop', () => {
  it('rejects loops with fewer than 4 points', () => {
    expect(isValidLoop([[0, 0], [1, 0], [0, 0]])).toBe(false)
  })

  it('rejects a tiny loop (< 0.01 km²)', () => {
    // Square ~10m × 10m ≈ 0.0001 km²
    const pts: Point[] = [
      [0, 0],
      [0.0001, 0],
      [0.0001, 0.0001],
      [0, 0.0001],
      [0, 0],
    ]
    expect(isValidLoop(pts)).toBe(false)
  })

  it('accepts a valid loop (~0.1 km²)', () => {
    // Square ~316m × 316m ≈ 0.1 km²
    const pts: Point[] = [
      [0, 0],
      [0.003, 0],
      [0.003, 0.003],
      [0, 0.003],
      [0, 0],
    ]
    expect(isValidLoop(pts)).toBe(true)
  })

  it('rejects an absurdly large loop (> 50 km²)', () => {
    const pts: Point[] = [
      [0,  0],
      [10, 0],
      [10, 10],
      [0,  10],
      [0,  0],
    ]
    expect(isValidLoop(pts)).toBe(false)
  })
})

// ─── calculateXP ─────────────────────────────────────────────────────────────

describe('calculateXP', () => {
  it('1 km² capture → 1000 XP', () => {
    expect(calculateXP(1, false)).toBe(1000)
  })

  it('0.1 km² capture → 100 XP', () => {
    expect(calculateXP(0.1, false)).toBe(100)
  })

  it('0.1 km² steal → 150 XP (100 base + 50 bonus)', () => {
    expect(calculateXP(0.1, true)).toBe(150)
  })

  it('0 km² → 0 XP', () => {
    expect(calculateXP(0, false)).toBe(0)
    expect(calculateXP(0, true)).toBe(0)
  })
})

// ─── computeLevel ────────────────────────────────────────────────────────────

describe('computeLevel', () => {
  // XP(n) = 100 × n^1.5
  // Level 1 → 0 XP
  // Level 2 → 100 × 2^1.5 ≈ 283 XP
  // Level 3 → 100 × 3^1.5 ≈ 520 XP
  // Level 5 → 100 × 5^1.5 ≈ 1118 XP
  // Level 10 → 100 × 10^1.5 ≈ 3162 XP

  it('0 XP → level 1', () => {
    expect(computeLevel(0)).toBe(1)
  })

  it('282 XP → level 1 (just below level 2)', () => {
    expect(computeLevel(282)).toBe(1)
  })

  it('283 XP → level 2', () => {
    expect(computeLevel(283)).toBe(2)
  })

  it('400 XP → level 2 (gaining 400 XP lands on level 2)', () => {
    expect(computeLevel(400)).toBe(2)
  })

  it('520 XP → level 3', () => {
    expect(computeLevel(520)).toBe(3)
  })

  it('3163 XP → level 10 (100 × 10^1.5 = 3162.28, so 3163 crosses threshold)', () => {
    expect(computeLevel(3163)).toBe(10)
  })
})
