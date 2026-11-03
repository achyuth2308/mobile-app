import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fueltracks/core/theme/app_theme.dart';
import 'package:fueltracks/data/models/vehicle.dart';
import 'package:fueltracks/features/dashboard/widgets/fleet_infographic_wheel.dart';
import 'package:fueltracks/features/dashboard/widgets/stat_tiles.dart';
import 'package:fueltracks/providers/fleet_provider.dart';

void main() {
  group('FleetInfographicWheel Widget Tests', () {
    testWidgets('renders 5 status labels and center total fleet count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: Center(
                child: FleetInfographicWheel(),
              ),
            ),
          ),
        ),
      );

      // Fast forward initial animations
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 800));

      // Verify the 5 petal status labels
      expect(find.text('MOVING'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);
      expect(find.text('STOPPED'), findsOneWidget);
      expect(find.text('NO DATA'), findsOneWidget);
      expect(find.text('OFFLINE'), findsOneWidget);

      // Verify center hub
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.textContaining('online'), findsOneWidget);
    });

    testWidgets('renders inside FleetOverviewCard cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: FleetOverviewCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('FLEET OVERVIEW'), findsOneWidget);
      expect(find.byType(FleetInfographicWheel), findsOneWidget);
    });
  });
}

