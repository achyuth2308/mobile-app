const fs = require('fs');
const path = require('path');

const targetFile = path.join(__dirname, '../lib/features/vehicle/vehicle_menu_screen.dart');
let content = fs.readFileSync(targetFile, 'utf8');

if (!content.includes('Manual Fuel Entry')) {
  const targetTag = "const _SectionHeader(label: 'VEHICLE OPERATIONS'),";
  const replacement = `const _SectionHeader(label: 'VEHICLE OPERATIONS'),

          _MenuItemCard(
            title: 'Manual Fuel Entry',
            subtitle: 'Log refill, level check & view mileage',
            icon: Icons.local_gas_station_rounded,
            accentColor: const Color(0xFFEA580C),
            badgeText: 'ESTIMATED',
            badgeColor: const Color(0xFFEA580C),
            onTap: () =>
                context.push('/vehicle/\${widget.vehicleId}/manual-fuel-entry'),
          ),
          const SizedBox(height: 5),`;

  content = content.replace(targetTag, replacement);
  fs.writeFileSync(targetFile, content, 'utf8');
  console.log('SUCCESS: vehicle_menu_screen.dart updated with Manual Fuel Entry tile.');
} else {
  console.log('ALREADY INCLUDED.');
}
