import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../../dashboard/widgets/vehicle_card.dart';

/// Compact live card shown when a marker is tapped.
///
/// It watches the vehicle provider directly, so the speed and address keep
/// updating in place while the sheet is open — no stale snapshot.
class VehiclePeekSheet extends ConsumerWidget {
  const VehiclePeekSheet({
    required this.vehicleId,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onOpenDetails,
    super.key,
  });

  final String vehicleId;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Vehicle? vehicle = ref.watch(vehicleByIdProvider(vehicleId));
    
    if (vehicle == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.md,
        0,
        Gap.md,
        MediaQuery.paddingOf(context).bottom + Gap.navClearance - 10,
      ),
      child: VehicleCard(
        vehicle: vehicle,
        glass: true,
        minimal: true,
        dense: true,
        onTap: onOpenDetails,
        onTrack: onToggleFollow,
      ),
    );
  }
}
