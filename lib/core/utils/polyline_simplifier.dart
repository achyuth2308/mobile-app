import 'dart:math';

/// Compresses a polyline using the Douglas-Peucker algorithm.
class PolylineSimplifier {
  /// Simplifies a list of GPS coordinates [lat, lng] using the Douglas-Peucker algorithm.
  /// The [epsilon] is the distance threshold in meters.
  static List<List<double>> simplify(List<List<double>> points, double epsilonMeters) {
    if (points.length <= 2) return points;

    double dmax = 0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double d = _perpendicularDistance(points[i], points[0], points[points.length - 1]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    if (dmax > epsilonMeters) {
      final List<List<double>> recResults1 = simplify(points.sublist(0, index + 1), epsilonMeters);
      final List<List<double>> recResults2 = simplify(points.sublist(index), epsilonMeters);

      return [...recResults1.sublist(0, recResults1.length - 1), ...recResults2];
    } else {
      return [points[0], points[points.length - 1]];
    }
  }

  static double _perpendicularDistance(List<double> pt, List<double> lineStart, List<double> lineEnd) {
    return _crossTrackDistance(
      pt[0], pt[1],
      lineStart[0], lineStart[1],
      lineEnd[0], lineEnd[1],
    );
  }

  static double _crossTrackDistance(double lat, double lng, double startLat, double startLng, double endLat, double endLng) {
    const double R = 6371e3; // Earth's radius in meters
    final d13 = _distance(startLat, startLng, lat, lng) / R;
    final theta13 = _bearing(startLat, startLng, lat, lng);
    final theta12 = _bearing(startLat, startLng, endLat, endLng);

    final dxt = asin(sin(d13) * sin(theta13 - theta12));
    return dxt.abs() * R;
  }

  static double _distance(double lat1, double lng1, double lat2, double lng2) {
    const double R = 6371e3;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _bearing(double lat1, double lng1, double lat2, double lng2) {
    final dLon = _toRadians(lng2 - lng1);
    final y = sin(dLon) * cos(_toRadians(lat2));
    final x = cos(_toRadians(lat1)) * sin(_toRadians(lat2)) -
        sin(_toRadians(lat1)) * cos(_toRadians(lat2)) * cos(dLon);
    return atan2(y, x);
  }

  static double _toRadians(double degree) => degree * pi / 180.0;
}
