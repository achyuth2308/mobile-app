import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/utils/gps_filter.dart';
import 'package:mobile_app/data/models/trip.dart';

void main() {
  group('GpsFilter.filterStationaryDrift', () {
    test('removes stationary GPS jitter around a parking location', () {
      final baseTime = DateTime(2026, 11, 5, 21, 9, 36);

      // Simulated scenario:
      // 1. Vehicle driving towards parking spot
      // 2. Arrives at parking spot (12.83400, 79.70300)
      // 3. 50 drift fixes fluctuating around parking spot (+- 10 meters, speed 0, ignition off)
      // 4. Vehicle resumes driving later
      final List<TrackPoint> rawPoints = [
        TrackPoint(
          latitude: 12.83000,
          longitude: 79.70000,
          timestamp: baseTime.subtract(const Duration(minutes: 5)),
          speed: 45.0,
          ignition: true,
        ),
        TrackPoint(
          latitude: 12.83200,
          longitude: 79.70150,
          timestamp: baseTime.subtract(const Duration(minutes: 2)),
          speed: 30.0,
          ignition: true,
        ),
        // Arrival / Parking point
        TrackPoint(
          latitude: 12.83400,
          longitude: 79.70300,
          timestamp: baseTime,
          speed: 0.0,
          ignition: false,
        ),
      ];

      // Add 40 jitter points within 15 meters while parked
      for (int i = 1; i <= 40; i++) {
        final double latOffset = (i % 2 == 0 ? 0.00005 : -0.00006);
        final double lngOffset = (i % 3 == 0 ? 0.00007 : -0.00005);
        rawPoints.add(
          TrackPoint(
            latitude: 12.83400 + latOffset,
            longitude: 79.70300 + lngOffset,
            timestamp: baseTime.add(Duration(minutes: i * 2)),
            speed: 0.0,
            ignition: false,
          ),
        );
      }

      // Driving away later
      rawPoints.add(
        TrackPoint(
          latitude: 12.83800,
          longitude: 79.70600,
          timestamp: baseTime.add(const Duration(hours: 2)),
          speed: 35.0,
          ignition: true,
        ),
      );

      final clean = GpsFilter.filterStationaryDrift(rawPoints);

      // We had 44 points total. The 40 jitter points while parked should all be filtered out!
      expect(clean.length, lessThanOrEqualTo(4));
      expect(clean.first.latitude, 12.83000);
      expect(clean.last.latitude, 12.83800);
    });

    test('suppresses ongoing parking jitter at the end of the route', () {
      final baseTime = DateTime(2026, 11, 5, 21, 9, 36);

      // Vehicle drives and parks at the end of the day (customer's exact case)
      final List<TrackPoint> rawPoints = [
        TrackPoint(
          latitude: 12.83000,
          longitude: 79.70000,
          timestamp: baseTime.subtract(const Duration(minutes: 5)),
          speed: 40.0,
          ignition: true,
        ),
        // Arrival point
        TrackPoint(
          latitude: 12.83400,
          longitude: 79.70300,
          timestamp: baseTime,
          speed: 0.0,
          ignition: false,
        ),
      ];

      // 100 jitter fixes over 3 hours of parking
      for (int i = 1; i <= 100; i++) {
        rawPoints.add(
          TrackPoint(
            latitude: 12.83400 + ((i % 5) * 0.00002),
            longitude: 79.70300 - ((i % 4) * 0.00003),
            timestamp: baseTime.add(Duration(minutes: i)),
            speed: 0.0,
            ignition: false,
          ),
        );
      }

      final clean = GpsFilter.filterStationaryDrift(rawPoints);

      // Only the driving point and the arrival parking point should remain
      expect(clean.length, 2);
      expect(clean[0].latitude, 12.83000);
      expect(clean[1].latitude, 12.83400);
    });
  });

  group('GpsFilter.filterAnomalies & cleanTrajectory', () {
    test('removes urban canyon multipath spikes across buildings', () {
      final baseTime = DateTime(2026, 11, 14, 10, 0, 0);

      // Scenario: Vehicle driving along Hitech City Main Road
      // Point 1: Road (17.44700, 78.37500) at 10:00:00, speed 30 km/h
      // Point 2: Glitch spike 120m away inside building (17.44800, 78.37400) at 10:00:03, speed 10 km/h
      // Point 3: Returns to road 20m ahead (17.44720, 78.37510) at 10:00:06, speed 32 km/h
      final List<TrackPoint> points = [
        TrackPoint(
          latitude: 17.44700,
          longitude: 78.37500,
          timestamp: baseTime,
          speed: 30.0,
          ignition: true,
        ),
        TrackPoint(
          latitude: 17.44800,
          longitude: 78.37400,
          timestamp: baseTime.add(const Duration(seconds: 3)),
          speed: 10.0,
          ignition: true,
        ),
        TrackPoint(
          latitude: 17.44720,
          longitude: 78.37510,
          timestamp: baseTime.add(const Duration(seconds: 6)),
          speed: 32.0,
          ignition: true,
        ),
      ];

      final clean = GpsFilter.filterAnomalies(points);

      // The glitch spike in the building must be discarded!
      expect(clean.length, 2);
      expect(clean[0].latitude, 17.44700);
      expect(clean[1].latitude, 17.44720);
    });

    test('cleanTrajectory cleans both multipath spikes and parking drift', () {
      final baseTime = DateTime(2026, 11, 14, 10, 0, 0);

      final List<TrackPoint> points = [
        // Driving
        TrackPoint(
          latitude: 17.44700,
          longitude: 78.37500,
          timestamp: baseTime,
          speed: 35.0,
          ignition: true,
        ),
        // Glitch spike into highrise
        TrackPoint(
          latitude: 17.45200,
          longitude: 78.37900,
          timestamp: baseTime.add(const Duration(seconds: 4)),
          speed: 5.0,
          ignition: true,
        ),
        // Driving continuation
        TrackPoint(
          latitude: 17.44750,
          longitude: 78.37530,
          timestamp: baseTime.add(const Duration(seconds: 8)),
          speed: 30.0,
          ignition: true,
        ),
        // Parking stop
        TrackPoint(
          latitude: 17.44800,
          longitude: 78.37550,
          timestamp: baseTime.add(const Duration(seconds: 20)),
          speed: 0.0,
          ignition: false,
        ),
        // 5 parking jitter fixes
        for (int i = 1; i <= 5; i++)
          TrackPoint(
            latitude: 17.44800 + (0.00003 * (i % 2 == 0 ? 1 : -1)),
            longitude: 78.37550 + (0.00003 * (i % 3 == 0 ? 1 : -1)),
            timestamp: baseTime.add(Duration(minutes: i)),
            speed: 0.0,
            ignition: false,
          ),
      ];

      final clean = GpsFilter.cleanTrajectory(points);

      // Should only contain the 2 road driving fixes and the 1 parking arrival fix
      expect(clean.length, 3);
      expect(clean[0].latitude, 17.44700);
      expect(clean[1].latitude, 17.44750);
      expect(clean[2].latitude, 17.44800);
    });

    test('suppresses toll plaza stop-and-go inching scribbles', () {
      final baseTime = DateTime(2026, 11, 14, 6, 10, 0);

      // Scenario: Vehicle arrives at toll booth, inched forward 3 times at 1-3 km/h within 20m, then drove away
      final List<TrackPoint> points = [
        // Approach toll plaza
        TrackPoint(
          latitude: 16.54000,
          longitude: 80.60000,
          timestamp: baseTime,
          speed: 40.0,
          ignition: true,
        ),
        // Stop at toll queue
        TrackPoint(
          latitude: 16.54100,
          longitude: 80.60100,
          timestamp: baseTime.add(const Duration(seconds: 15)),
          speed: 0.0,
          ignition: true,
        ),
        // Inching forward 3m (speed 2 km/h) with 15m GPS jitter
        TrackPoint(
          latitude: 16.54112,
          longitude: 80.60085,
          timestamp: baseTime.add(const Duration(seconds: 35)),
          speed: 2.0,
          ignition: true,
        ),
        // Inching forward 4m (speed 3 km/h) with 20m GPS jitter
        TrackPoint(
          latitude: 16.54118,
          longitude: 80.60115,
          timestamp: baseTime.add(const Duration(seconds: 55)),
          speed: 3.0,
          ignition: true,
        ),
        // Accelerating and driving away on highway (speed 35 km/h, moved 80m away)
        TrackPoint(
          latitude: 16.54180,
          longitude: 80.60180,
          timestamp: baseTime.add(const Duration(seconds: 90)),
          speed: 35.0,
          ignition: true,
        ),
      ];

      final clean = GpsFilter.cleanTrajectory(points);

      // The 2 intermediate toll queue inching jitter points must be suppressed!
      // Only approach, single toll stop anchor, and highway departure should exist.
      expect(clean.length, 3);
      expect(clean[0].latitude, 16.54000);
      expect(clean[1].latitude, 16.54100);
      expect(clean[2].latitude, 16.54180);
    });

    test('smoothTrajectory pulls lateral GPS antenna jitter onto the roadway', () {
      final baseTime = DateTime(2026, 11, 14, 10, 20, 0);

      // Straight north highway: Lat increases steadily, Lng should stay 80.60000
      // Point 2 has a 15m lateral wobble to the west (80.59985 instead of 80.60000)
      final List<TrackPoint> points = [
        TrackPoint(
          latitude: 16.54000,
          longitude: 80.60000,
          timestamp: baseTime,
          speed: 30.0,
          ignition: true,
        ),
        TrackPoint(
          latitude: 16.54100,
          longitude: 80.59985, // 15m wobble into roadside building
          timestamp: baseTime.add(const Duration(seconds: 5)),
          speed: 30.0,
          ignition: true,
        ),
        TrackPoint(
          latitude: 16.54200,
          longitude: 80.60000,
          timestamp: baseTime.add(const Duration(seconds: 10)),
          speed: 30.0,
          ignition: true,
        ),
      ];

      final smoothed = GpsFilter.smoothTrajectory(points);

      expect(smoothed.length, 3);
      // The 15m lateral bump (80.59985) is smoothed much closer to 80.60000
      expect(smoothed[1].longitude, greaterThan(80.59990));
    });
  });
}

