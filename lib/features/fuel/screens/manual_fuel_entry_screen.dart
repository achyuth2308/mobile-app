import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../services/fuel_service.dart';

class ManualFuelEntryScreen extends ConsumerStatefulWidget {
  const ManualFuelEntryScreen({super.key, this.initialVehicleId});

  final String? initialVehicleId;

  @override
  ConsumerState<ManualFuelEntryScreen> createState() =>
      _ManualFuelEntryScreenState();
}

class _ManualFuelEntryScreenState extends ConsumerState<ManualFuelEntryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedVehicleId;
  String _entryType = 'REFILL'; // 'INITIAL', 'REFILL', 'RECONCILIATION'

  final TextEditingController _tankFuelController = TextEditingController();
  final TextEditingController _fuelFilledController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  bool _loadingState = false;
  bool _submitting = false;
  Map<String, dynamic>? _fuelState;
  List<Map<String, dynamic>> _historyEntries = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.initialVehicleId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
      if (_selectedVehicleId == null && vehicles.isNotEmpty) {
        setState(() {
          _selectedVehicleId = vehicles.first.id;
        });
      }
      if (_selectedVehicleId != null) {
        _loadVehicleFuelData(_selectedVehicleId!);
      }
    });
  }

  @override
  void dispose() {
    _tankFuelController.dispose();
    _fuelFilledController.dispose();
    _odometerController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleFuelData(String vehicleId) async {
    setState(() => _loadingState = true);
    final FuelService fuelService = ref.read(fuelServiceProvider);
    final Map<String, dynamic>? state =
        await fuelService.getManualFuelState(vehicleId);
    final List<Map<String, dynamic>> history =
        await fuelService.getManualFuelEntries(vehicleId);

    if (mounted) {
      setState(() {
        _fuelState = state;
        _historyEntries = history;
        _loadingState = false;
        // Prefill odometer if available
        if (state != null && state['last_known_odometer'] != null) {
          _odometerController.text =
              state['last_known_odometer'].toString();
        }
      });
    }
  }

  Future<void> _submitEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }

    final double? tankQty = double.tryParse(_tankFuelController.text.trim());
    final double? filledQty = double.tryParse(_fuelFilledController.text.trim());
    final double? odo = double.tryParse(_odometerController.text.trim());

    if (tankQty == null || tankQty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid fuel quantity')),
      );
      return;
    }

    if (odo == null || odo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid odometer reading')),
      );
      return;
    }

    // Capacity limit check
    final double maxCap = _fuelState != null && _fuelState!['tank_capacity'] != null
        ? (double.tryParse(_fuelState!['tank_capacity'].toString()) ?? 500.0)
        : 500.0;

    if (tankQty > maxCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Fuel quantity cannot exceed tank capacity (${maxCap.toStringAsFixed(1)} L)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final FuelService fuelService = ref.read(fuelServiceProvider);
      await fuelService.submitManualFuelEntry(
        vehicleId: _selectedVehicleId!,
        entryType: _entryType,
        fuelQuantity: tankQty,
        fuelFilled: _entryType == 'REFILL' ? (filledQty ?? 0.0) : 0.0,
        odometer: odo,
        remarks: _remarksController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fuel entry recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _tankFuelController.clear();
        _fuelFilledController.clear();
        _remarksController.clear();

        // Refresh state
        await _loadVehicleFuelData(_selectedVehicleId!);
        await ref.read(fleetProvider.notifier).load(silent: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Healthy':
        return Colors.green;
      case 'Normal':
        return Colors.blue;
      case 'Low Fuel':
        return Colors.amber.shade700;
      case 'Critical Fuel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Vehicle> vehicles = ref.watch(fleetProvider).vehicles;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Driver Fuel Entry',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Informational Disclaimer Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'ESTIMATED FUEL MONITORING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Note: Fuel values are estimated based on driver manual entries and GPS distance calculation. Physical fuel sensors are not installed.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade900,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Vehicle Selector Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVehicleId,
                      isExpanded: true,
                      hint: const Text('Select Vehicle'),
                      items: vehicles.map((Vehicle v) {
                        return DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(
                            '${v.name ?? v.plate} (${v.plate})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? val) {
                        if (val != null) {
                          setState(() => _selectedVehicleId = val);
                          _loadVehicleFuelData(val);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Live Fuel Status & Mileage Preview Card
                if (_loadingState)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_fuelState != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Current Estimated State',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(_fuelState!['fuel_status']?.toString()).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(_fuelState!['fuel_status']?.toString()).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _fuelState!['fuel_status']?.toString() ?? 'No Data',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(_fuelState!['fuel_status']?.toString()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _MetricTile(
                                label: 'Estimated Fuel',
                                value: _fuelState!['current_fuel'] != null
                                    ? '${double.tryParse(_fuelState!['current_fuel'].toString())?.toStringAsFixed(1) ?? '0.0'} L'
                                    : 'N/A',
                                subtext: _fuelState!['tank_capacity'] != null
                                    ? '/ ${_fuelState!['tank_capacity']} L tank'
                                    : null,
                                color: Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricTile(
                                label: 'Est. Range',
                                value: _fuelState!['estimated_range_km'] != null
                                    ? '${_fuelState!['estimated_range_km']} km'
                                    : 'N/A',
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricTile(
                                label: 'Avg Mileage',
                                value: _fuelState!['current_mileage'] != null
                                    ? '${double.tryParse(_fuelState!['current_mileage'].toString())?.toStringAsFixed(1) ?? '0.0'} km/l'
                                    : 'N/A',
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                // Entry Type Segmented Chips
                const Text(
                  'Entry Type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _TypeChip(
                      label: 'Refill',
                      selected: _entryType == 'REFILL',
                      icon: Icons.local_gas_station,
                      onTap: () => setState(() => _entryType = 'REFILL'),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'Level Check',
                      selected: _entryType == 'RECONCILIATION',
                      icon: Icons.tune,
                      onTap: () => setState(() => _entryType = 'RECONCILIATION'),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'Initial Setup',
                      selected: _entryType == 'INITIAL',
                      icon: Icons.flag,
                      onTap: () => setState(() => _entryType = 'INITIAL'),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Form Inputs Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: <Widget>[
                      // Tank Fuel Level
                      TextFormField(
                        controller: _tankFuelController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: _entryType == 'REFILL'
                              ? 'Tank Level After Refill (Litres) *'
                              : 'Current Fuel in Tank (Litres) *',
                          hintText: 'e.g. 75.0',
                          prefixIcon: const Icon(Icons.water_drop, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (String? val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Required';
                          }
                          final double? n = double.tryParse(val.trim());
                          if (n == null || n < 0) return 'Invalid quantity';
                          return null;
                        },
                      ),

                      if (_entryType == 'REFILL') ...<Widget>[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _fuelFilledController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Fuel Filled (Litres) *',
                            hintText: 'e.g. 40.0',
                            prefixIcon: const Icon(Icons.add_circle_outline, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (String? val) {
                            if (_entryType == 'REFILL') {
                              if (val == null || val.trim().isEmpty) return 'Required for refill';
                              final double? n = double.tryParse(val.trim());
                              if (n == null || n <= 0) return 'Must be > 0';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Odometer Reading
                      TextFormField(
                        controller: _odometerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Vehicle Odometer Reading (KM) *',
                          hintText: 'e.g. 45200',
                          prefixIcon: const Icon(Icons.speed, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (String? val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final double? n = double.tryParse(val.trim());
                          if (n == null || n < 0) return 'Invalid reading';
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Remarks
                      TextFormField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          labelText: 'Remarks (Optional)',
                          hintText: 'e.g. Fuel station, receipt no.',
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitEntry,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _submitting ? 'Recording...' : 'Save Fuel Entry',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Entries Audit History
                if (_historyEntries.isNotEmpty) ...<Widget>[
                  const Text(
                    'Recent Entries History',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _historyEntries.length > 5 ? 5 : _historyEntries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> entry = _historyEntries[index];
                        final String type = entry['entry_type']?.toString() ?? '';
                        final String qty = entry['fuel_quantity']?.toString() ?? '0';
                        final String time = entry['entry_time']?.toString() ?? '';
                        final String diff = entry['fuel_difference']?.toString() ?? '0';

                        return ListTile(
                          dense: true,
                          title: Row(
                            children: <Widget>[
                              Text(
                                '$qty L',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Odo: ${entry['odometer']} km • $time',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: double.tryParse(diff) != null && double.parse(diff) != 0.0
                              ? Text(
                                  'Diff: ${double.parse(diff) > 0 ? '+' : ''}$diff L',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: double.parse(diff) < 0 ? Colors.red : Colors.green,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.subtext,
    required this.color,
  });

  final String label;
  final String value;
  final String? subtext;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          if (subtext != null)
            Text(
              subtext!,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEA580C) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
