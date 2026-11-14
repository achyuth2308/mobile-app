import 'package:latlong2/latlong.dart';

import '../../data/models/trip.dart';

/// Utility class for cleaning GPS trajectories, eliminating urban multipath spikes,
/// and filtering stationary drift / jitter (spiderwebbing).
class GpsFilter {
  /// Cleans a full GPS trajectory by:
  /// 1. Removing multipath spikes and teleports (filterAnomalies)
  /// 2. Locking toll plaza queues, traffic jams, and parking stops (filterStationaryDrift)
  /// 3. Applying road corridor smoothing to eliminate 10-15m off-road lateral drift (smoothTrajectory)
  static List<TrackPoint> cleanTrajectory(
    List<TrackPoint> points, {
    double stationarySpeedThresholdKph = 5.0,
    double driftRadiusMeters = 35.0,
    double maxSpeedKmph = 120.0,
  }) {
    if (points.length <= 1) return points;

    // Phase 1: Filter out multipath spikes, teleports, and impossible GPS jumps
    final List<TrackPoint> anomalyCleaned = filterAnomalies(
      points,
      maxSpeedKmph: maxSpeedKmph,
    );

    // Phase 2: Lock stationary drift, parking jitter, and toll plaza queues
    final List<TrackPoint> stationaryLocked = filterStationaryDrift(
      anomalyCleaned,
      stationarySpeedThresholdKph: stationarySpeedThresholdKph,
      driftRadiusMeters: driftRadiusMeters,
    );

    // Phase 3: Road corridor smoothing (eliminates 10-15m lateral off-road wobble on highways)
    return smoothTrajectory(stationaryLocked);
  }

  /// Spatial anomaly & spike filter: detects and removes impossible jumps caused by
  /// urban canyon multipath reflections (satellite signals bouncing off high-rises),
  /// cell-tower LBS fallback, and transient GPS errors.
  ///
  /// Uses a 3-point temporal-spatial analysis:
  /// If a candidate point jumps at impossible implied speeds, or spikes into a building
  /// and returns to the roadway in subsequent fixes, the spike point is eliminated.
  static List<TrackPoint> filterAnomalies(
    List<TrackPoint> points, {
    double maxSpeedKmph = 120.0,
    double jumpDistanceMeters = 60.0,
  }) {
    if (points.length <= 2) return points;

    // Ensure chronological order
    final List<TrackPoint> sorted = List<TrackPoint>.from(points)
      ..sort((TrackPoint a, TrackPoint b) => a.timestamp.compareTo(b.timestamp));

    const Distance distCalc = Distance();
    final List<TrackPoint> clean = <TrackPoint>[];
    int consecutiveRejects = 0;

    for (int i = 0; i < sorted.length; i++) {
      final TrackPoint p = sorted[i];
      if (!p.isValid) continue;

      if (clean.isEmpty) {
        clean.add(p);
        continue;
      }

      final TrackPoint prev = clean.last;
      final double distMeters = distCalc(prev.latLng, p.latLng);
      final double timeDiffSec =
          (p.timestamp.difference(prev.timestamp).inMilliseconds.abs()) / 1000.0;

      // ───────────────────────────────────────────────────────────────────────
      // IGNITION-OFF LBS PHANTOM FILTER
      // When ignition is OFF, the engine is physically stopped.
      // The GPS tracker falls back to GSM cell-tower LBS which is 100-500m inaccurate.
      // The device also reports a FAKE speed (calculated from two LBS positions).
      // Lock hard: reject ALL positions > 80m from the last confirmed fix
      // when ignition is off and the previous anchor was also ignition-off (overnight park).
      // ───────────────────────────────────────────────────────────────────────
      if (!p.ignition && !prev.ignition && distMeters > 80.0) {
        // Overnight LBS phantom: ignore completely, do not shift anchor
        continue;
      }
      // Even if ignition just turned off, any jump > 150m at < 15 km/h is LBS drift
      if (!p.ignition && distMeters > 150.0 && p.speed < 15.0) {
        continue;
      }

      // Implied speed between previous accepted fix and candidate fix
      final double impliedSpeedKmph = timeDiffSec > 0
          ? (distMeters / 1000.0) / (timeDiffSec / 3600.0)
          : (distMeters > 30.0 ? double.infinity : 0.0);

      // Detect impossible multipath jump / anomaly:
      // 1) Implied speed exceeds commercial vehicle limit (> 120 km/h) over a significant jump (> 60m)
      // 2) Teleport jump: implied speed > 80 km/h while device reports crawling/stopped (< 20 km/h) over > 50m
      // 3) Sudden jump (> 300m) in short duration (< 10 sec)
      final bool isAnomaly = (impliedSpeedKmph > maxSpeedKmph && distMeters > jumpDistanceMeters) ||
          (impliedSpeedKmph > 80.0 && p.speed < 20.0 && distMeters > 50.0) ||
          (distMeters > 300.0 && timeDiffSec < 10.0);

      if (isAnomaly) {
        // 3-point V-spike resolution: check if `prev` was the glitch that got accepted
        if (clean.length >= 2) {
          final TrackPoint prevPrev = clean[clean.length - 2];
          final double distPrevPrev = distCalc(prevPrev.latLng, p.latLng);
          final double timeDiffPrevPrev =
              (p.timestamp.difference(prevPrev.timestamp).inMilliseconds.abs()) / 1000.0;
          final double speedPrevPrev = timeDiffPrevPrev > 0
              ? (distPrevPrev / 1000.0) / (timeDiffPrevPrev / 3600.0)
              : (distPrevPrev > 30.0 ? double.infinity : 0.0);

          // If current point aligns cleanly with prevPrev, `prev` was the spike into a building!
          if (speedPrevPrev < maxSpeedKmph) {
            clean.removeLast(); // Discard the spike point
            clean.add(p);       // Accept true current roadway point
            consecutiveRejects = 0;
            continue;
          }
        }

        consecutiveRejects++;
        // If persistent over > 3 fixes, vehicle genuinely relocated (e.g. towed or tunnel exit)
        if (consecutiveRejects > 3) {
          clean.add(p);
          consecutiveRejects = 0;
        }
        continue; // Reject anomaly
      }

      consecutiveRejects = 0;
      clean.add(p);
    }

    return clean;
  }

  /// Filters out stationary GPS drift / jitter (spiderwebbing), parking overnight LBS phantom
  /// positions, toll plaza stop-and-go inching, and traffic queue scribbles.
  ///
  /// Uses a layered lock system:
  /// - **Ignition-OFF Hard Lock:** When engine is off, ALL LBS phantom drifts within 200m
  ///   are suppressed. The device reports fake 6-9 km/h speed from sequential LBS cell-tower
  ///   positions — this lock eliminates overnight spiderwebs completely.
  /// - **Toll Plaza & Traffic Queue Lock:** While ignition is on but speed ≤ 3.5 km/h,
  ///   locks to entry anchor within 45m radius until real highway departure (≥ 30m AND > 8 km/h).
  static List<TrackPoint> filterStationaryDrift(
    List<TrackPoint> points, {
    double stationarySpeedThresholdKph = 5.0,
    double driftRadiusMeters = 35.0,
  }) {
    if (points.length <= 1) return points;

    const Distance distCalc = Distance();
    final List<TrackPoint> clean = <TrackPoint>[];

    TrackPoint? anchor;
    bool isStationary = false;
    bool isIgnitionOff = false;

    for (final TrackPoint pt in points) {
      if (!pt.isValid) continue;

      if (clean.isEmpty) {
        clean.add(pt);
        anchor = pt;
        isStationary = pt.speed <= stationarySpeedThresholdKph;
        isIgnitionOff = !pt.ignition;
        continue;
      }

      final double distFromAnchor = distCalc(anchor!.latLng, pt.latLng);

      // ───────────────────────────────────────────────────────────────────────
      // IGNITION-OFF HARD LOCK
      // When the engine is physically OFF, the vehicle CANNOT move.
      // Any reported positions are LBS cell-tower phantom drifts (accuracy 100-500m).
      // The device fakes speed by computing delta between two LBS positions.
      // FIX: When ignition is off, suppress everything within 200m of the last anchor.
      // This eliminates overnight parking spiderwebs completely.
      // ───────────────────────────────────────────────────────────────────────
      if (!pt.ignition) {
        if (!isIgnitionOff) {
          // Engine just turned off — lock the final parking position as anchor
          isIgnitionOff = true;
          isStationary = true;
          anchor = pt;
          if (distCalc(clean.last.latLng, pt.latLng) >= 3.0) {
            clean.add(pt);
          }
        } else {
          // Engine remains off: suppress ALL LBS phantom drifts within 200m
          // (LBS accuracy is 100-500m so this is the right hard lock radius)
          if (distFromAnchor < 200.0) {
            continue; // Drop — purely LBS ghost position
          }
          // Beyond 200m with ignition still off = genuine tow/relocation
          anchor = pt;
        }
        continue;
      }

      // Engine is ON from this point forward
      if (isIgnitionOff) {
        // Ignition just turned ON after being off — engine restarted
        isIgnitionOff = false;
        isStationary = false;
        anchor = pt;
        clean.add(pt);
        continue;
      }

      final bool isLowSpeed = pt.speed <= stationarySpeedThresholdKph;

      if (isLowSpeed) {
        if (!isStationary) {
          // Transition from moving to stationary / queue state
          isStationary = true;
          anchor = pt;
          // Ensure the polyline reaches this stop location
          if (distCalc(clean.last.latLng, pt.latLng) >= 3.0) {
            clean.add(pt);
          }
        } else {
          // Vehicle is stationary or inching in a toll queue.
          // STOP LOCK: Suppress ALL jitter within 45m. Never shift anchor.
          if (distFromAnchor < 45.0) {
            continue;
          }
          // Only relocate anchor if vehicle truly crept forward > 45m
          anchor = pt;
        }
      } else {
        // Vehicle is reporting speed > stationarySpeedThresholdKph
        if (isStationary) {
          // HYSTERESIS DEPARTURE GATE:
          // Enter stationary at <= 3.5 km/h, but only EXIT when genuinely committed to moving:
          // speed > 15 km/h AND moved >= 40m from anchor.
          // This prevents oscillation at traffic signals where speed bounces between 4-9 km/h,
          // which was causing small remaining spiderweb clusters at every Hitech City signal.
          final bool hasRealSpeed = pt.speed > 15.0;
          final bool hasRealDistance = distFromAnchor >= 40.0;
          if (hasRealSpeed && hasRealDistance) {
            isStationary = false;
            anchor = pt;
            clean.add(pt);
          }
          // If speed is 5-15 km/h, treat as still part of the stop (slow crawl / signal roll)
        } else {
          // Normal moving path: skip negligible sub-meter micro-noise
          if (distCalc(clean.last.latLng, pt.latLng) >= 2.5) {
            clean.add(pt);
            anchor = pt;
          }
        }
      }
    }

    return clean;
  }

  /// Road corridor smoothing: eliminates high-frequency lateral GPS noise (10-15m off-road wobble)
  /// for moving vehicles along highways, bypasses, and straightaways.
  ///
  /// Uses a 2-pass Laplacian binomial smoothing filter:
  ///   P'_i = 0.25 * P_{i-1} + 0.50 * P_i + 0.25 * P_{i+1}
  /// This gently pulls lateral GPS noise back onto the central corridor of travel
  /// without rounding off intersection corners or affecting stopped locations.
  static List<TrackPoint> smoothTrajectory(List<TrackPoint> points) {
    if (points.length <= 2) return points;

    const Distance distCalc = Distance();
    final List<TrackPoint> result = List<TrackPoint>.from(points);

    // 2-pass gentle road corridor smoothing on moving segments
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 1; i < result.length - 1; i++) {
        final TrackPoint prev = result[i - 1];
        final TrackPoint curr = result[i];
        final TrackPoint next = result[i + 1];

        // Only smooth actively moving vehicle trajectory points (speed > 5 km/h)
        if (curr.speed < 5.0 || prev.speed < 5.0 || next.speed < 5.0) continue;

        // Do not smooth across large missing telemetry gaps (> 250m or > 2 minutes)
        final double distPrev = distCalc(prev.latLng, curr.latLng);
        final double distNext = distCalc(curr.latLng, next.latLng);
        if (distPrev > 250.0 || distNext > 250.0) continue;

        final Duration timeDiff = next.timestamp.difference(prev.timestamp).abs();
        if (timeDiff.inMinutes > 2) continue;

        // Weighted moving average: 25% prev + 50% curr + 25% next
        final double smoothLat =
            0.25 * prev.latitude + 0.50 * curr.latitude + 0.25 * next.latitude;
        final double smoothLng =
            0.25 * prev.longitude + 0.50 * curr.longitude + 0.25 * next.longitude;

        result[i] = TrackPoint(
          latitude: smoothLat,
          longitude: smoothLng,
          timestamp: curr.timestamp,
          speed: curr.speed,
          heading: curr.heading,
          ignition: curr.ignition,
          address: curr.address,
        );
      }
    }

    return result;
  }
}

