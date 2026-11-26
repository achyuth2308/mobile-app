const fs = require('fs');
const path = require('path');

const targetFile = path.join(__dirname, '../lib/core/router/app_router.dart');
let content = fs.readFileSync(targetFile, 'utf8');

if (!content.includes('ManualFuelEntryScreen')) {
  // 1. Add import
  content = content.replace(
    "import '../../features/fuel/screens/fuel_analytics_screen.dart';",
    "import '../../features/fuel/screens/fuel_analytics_screen.dart';\nimport '../../features/fuel/screens/manual_fuel_entry_screen.dart';"
  );

  // 2. Add route inside vehicle routes:
  content = content.replace(
    "path: 'fuel-analytics',",
    "path: 'manual-fuel-entry',\n            builder: (BuildContext c, GoRouterState s) =>\n                ManualFuelEntryScreen(initialVehicleId: s.pathParameters['id']),\n          ),\n          GoRoute(\n            path: 'fuel-analytics',"
  );

  // 3. Add top-level route before /fuel-analytics:
  content = content.replace(
    "path: '/fuel-analytics',",
    "path: '/manual-fuel-entry',\n          parentNavigatorKey: _rootKey,\n          builder: (BuildContext c, GoRouterState s) => ManualFuelEntryScreen(\n            initialVehicleId: s.uri.queryParameters['vehicle'] ??\n                s.uri.queryParameters['vehicleId'],\n          ),\n        ),\n        GoRoute(\n          path: '/fuel-analytics',"
  );

  fs.writeFileSync(targetFile, content, 'utf8');
  console.log('SUCCESS: app_router.dart updated.');
} else {
  console.log('ALREADY INCLUDED.');
}
