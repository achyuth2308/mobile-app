import '../../data/models/vehicle.dart';

/// Utilities for resolving subscription license tiers from vehicle metadata.
/// Strictly follows production rules from `fueltracks1/frontend/src/utils/licenseUtils.js`.
class LicenseTierUtils {
  LicenseTierUtils._();

  /// Returns the license tier ('Standard' | 'Standard Pro' | 'Advanced' | 'Premium') for a vehicle.
  static String getVehicleLicenseTier(Vehicle v) {
    final Map<String, dynamic> raw = v.raw;
    final dynamic metaRaw = raw['metadata'];
    final Map<String, dynamic> meta = (metaRaw is Map<String, dynamic>)
        ? metaRaw
        : (metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : <String, dynamic>{});

    // 1. Explicit licenceType check (case-insensitive)
    final String explicitType = (meta['licenceType'] ??
            meta['licence_type'] ??
            raw['licenceType'] ??
            raw['licence_type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    if (explicitType == 'standard pro' ||
        explicitType == 'starter' ||
        explicitType.contains('standard pro') ||
        explicitType.contains('starter')) {
      return 'Standard Pro';
    }
    if (explicitType == 'standard' ||
        explicitType == 'basic' ||
        explicitType.contains('standard') ||
        explicitType.contains('basic')) {
      return 'Standard';
    }
    if (explicitType == 'advanced' || explicitType.contains('advanced')) {
      return 'Advanced';
    }
    if (explicitType == 'premium' ||
        explicitType == 'enterprise' ||
        explicitType.contains('premium') ||
        explicitType.contains('enterprise')) {
      return 'Premium';
    }

    // 2. Licence ID prefix check:
    // BC = Standard (formerly Basic)
    // ST = Standard Pro (formerly Starter)
    // AD = Advanced
    // EN / PR = Premium
    final String licId = (meta['licenceId'] ??
            meta['licence_id'] ??
            meta['licenceNo'] ??
            meta['licence_no'] ??
            raw['licenceId'] ??
            raw['licence_id'] ??
            raw['licenceNo'] ??
            raw['licence_no'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();

    if (licId.startsWith('ST')) return 'Standard Pro';
    if (licId.startsWith('BC')) return 'Standard';
    if (licId.startsWith('AD')) return 'Advanced';
    if (licId.startsWith('EN') || licId.startsWith('PR')) return 'Premium';

    return 'Standard';
  }

  /// Resolves the overall fleet tier.
  /// If the customer has Standard or Standard Pro vehicles, they resolve to that tier.
  static String resolveLicenseTier(List<Vehicle> vehicles) {
    if (vehicles.isEmpty) return 'Standard';

    int advancedCount = 0;
    int premiumCount = 0;
    int standardProCount = 0;
    int standardCount = 0;

    for (final Vehicle v in vehicles) {
      final String t = getVehicleLicenseTier(v);
      if (t == 'Premium') {
        premiumCount++;
      } else if (t == 'Advanced') {
        advancedCount++;
      } else if (t == 'Standard Pro') {
        standardProCount++;
      } else {
        standardCount++;
      }
    }

    // If all or predominant vehicles are Advanced/Premium, resolve to that tier
    if (premiumCount > 0 && standardCount == 0 && standardProCount == 0) {
      return 'Premium';
    }
    if (advancedCount > 0 && standardCount == 0 && standardProCount == 0) {
      return 'Advanced';
    }
    if (standardProCount > 0) {
      return 'Standard Pro';
    }
    return 'Standard';
  }

  /// Whether the resolved tier includes WhatsApp alerts for free.
  /// STRICT: Only Advanced and Premium include free WhatsApp alerts.
  /// Standard and Standard Pro are NEVER free; customer must purchase add-on.
  static bool isWhatsAppIncluded(String tier) {
    final String t = tier.trim().toLowerCase();
    if (t.contains('standard') ||
        t.contains('basic') ||
        t.contains('starter') ||
        t.contains('pro') ||
        t.contains('plus')) {
      return false;
    }
    return t.contains('advanced') ||
        t.contains('premium') ||
        t.contains('enterprise');
  }
}
