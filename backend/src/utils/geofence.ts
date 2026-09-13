const EARTH_RADIUS_METERS = 6_371_000;

export interface LatLng {
  latitude: number;
  longitude: number;
}

/** Local Haversine distance in meters (no external Maps API). */
export function haversineDistanceMeters(a: LatLng, b: LatLng): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);

  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  return EARTH_RADIUS_METERS * c;
}

export function isWithinGeofence(point: LatLng, center: LatLng, radiusMeters: number): boolean {
  return haversineDistanceMeters(point, center) <= radiusMeters;
}
