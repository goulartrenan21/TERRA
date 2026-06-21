// ─── GeoJSON primitives ──────────────────────────────────────────────────────

export interface GeoPoint {
  type: 'Point'
  coordinates: [number, number] // [lng, lat]
}

export interface GeoLineString {
  type: 'LineString'
  coordinates: [number, number][]
}

export interface GeoPolygon {
  type: 'Polygon'
  coordinates: [number, number][][]
}

// ─── Activity ────────────────────────────────────────────────────────────────

export type ActivityStatus = 'processing' | 'done' | 'failed'

export interface ActivityMetrics {
  distanceM: number
  durationS: number
  avgPaceSecPerKm: number
  elevationM?: number
}

export interface Activity {
  id: string
  userId: string
  path: GeoLineString
  metrics: ActivityMetrics
  status: ActivityStatus
  startedAt: string   // ISO 8601
  endedAt: string     // ISO 8601
  createdAt: string
}

export interface PostActivityRequest {
  polyline: GeoLineString
  metrics: ActivityMetrics
  startedAt: string
  endedAt: string
}

export interface PostActivityResponse {
  activityId: string
  status: ActivityStatus
}

// ─── Territory ───────────────────────────────────────────────────────────────

export interface Territory {
  id: string
  ownerId: string | null
  ownerName?: string
  ownerAvatarUrl?: string
  geom: GeoPolygon
  areaKm2: number
  freshness: number   // 0.0 – 1.0
  capturedAt: string
  defendedAt: string
}

export interface TerritoriesResponse {
  type: 'FeatureCollection'
  features: TerritoryFeature[]
}

export interface TerritoryFeature {
  type: 'Feature'
  geometry: GeoPolygon
  properties: Omit<Territory, 'geom'>
}

export type TerritoryEventType = 'captured' | 'stolen' | 'reinforced' | 'decayed' | 'expired'

export interface TerritoryEvent {
  id: string
  territoryId: string
  activityId: string
  eventType: TerritoryEventType
  oldOwnerId: string | null
  newOwnerId: string | null
  areaKm2: number
  createdAt: string
}

// ─── User / Profile ──────────────────────────────────────────────────────────

export interface UserProfile {
  id: string
  email: string
  displayName: string
  avatarUrl: string | null
  xp: number
  level: number
  streakDays: number
  streakFreezes: number
  neighborhoodId: string | null
  totalAreaKm2: number
  territoryCount: number
  createdAt: string
}

export interface UpdateProfileRequest {
  displayName?: string
  avatarUrl?: string
  neighborhoodId?: string
  privacyZones?: PrivacyZone[]
}

export interface PrivacyZone {
  lat: number
  lng: number
  radiusM: number
  label?: string
}

// ─── Ranking ─────────────────────────────────────────────────────────────────

export type RankingScope = 'neighborhood' | 'city' | 'country'
export type RankingWindow = 'week' | 'alltime'

export interface RankingEntry {
  position: number
  userId: string
  displayName: string
  avatarUrl: string | null
  totalAreaKm2: number
  territoryCount: number
}

export interface RankingResponse {
  scope: RankingScope
  window: RankingWindow
  windowStart: string
  windowEnd: string
  entries: RankingEntry[]
  currentUserPosition: number | null
}

// ─── Feed ────────────────────────────────────────────────────────────────────

export interface ActivityPost {
  id: string
  activityId: string
  userId: string
  displayName: string
  avatarUrl: string | null
  path: GeoLineString
  metrics: ActivityMetrics
  capturedAreaKm2: number
  xpGained: number
  likeCount: number
  commentCount: number
  likedByMe: boolean
  createdAt: string
}

export interface FeedResponse {
  posts: ActivityPost[]
  nextCursor: string | null
}

// ─── Notifications ───────────────────────────────────────────────────────────

export type NotificationType =
  | 'territory_stolen'
  | 'streak_warning'
  | 'kudos'
  | 'level_up'
  | 'capture_done'

export interface Notification {
  id: string
  userId: string
  type: NotificationType
  payload: Record<string, unknown>
  read: boolean
  createdAt: string
}

// ─── Capture Job ─────────────────────────────────────────────────────────────

export interface CaptureJobData {
  activityId: string
  userId: string
  polyline: GeoLineString
}

export interface CaptureResult {
  activityId: string
  capturedAreas: CapturedArea[]
  stolenFrom: StolenArea[]
  xpGained: number
  newLevel: number
  leveledUp: boolean
  streakUpdated: boolean
}

export interface CapturedArea {
  territoryId: string
  areaKm2: number
  geom: GeoPolygon
}

export interface StolenArea {
  territoryId: string
  fromUserId: string
  fromDisplayName: string
  areaKm2: number
}

// ─── WebSocket messages ──────────────────────────────────────────────────────

export type WsMessage =
  | { type: 'capture_done';      payload: CaptureResult }
  | { type: 'territory_stolen';  payload: { territoryId: string; byUserId: string; byDisplayName: string; areaKm2: number } }
  | { type: 'streak_warning';    payload: { streakDays: number; hoursLeft: number } }
  | { type: 'kudos';             payload: { fromUserId: string; fromDisplayName: string; activityId: string } }

// ─── Device (FCM/APNs) ───────────────────────────────────────────────────────

export type DevicePlatform = 'android' | 'ios'

export interface RegisterDeviceRequest {
  token: string
  platform: DevicePlatform
}

// ─── Streak ──────────────────────────────────────────────────────────────────

export interface StreakCheckinResponse {
  streakDays: number
  freezesRemaining: number
  message: string
}
