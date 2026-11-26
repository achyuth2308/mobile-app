import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vehicle.dart';
import '../../../providers/fleet_provider.dart';
import '../services/fuel_service.dart';

/// Screen matching the FuelTracks Web Portal Manual Fuel Entry (`app.fueltracks.in/fuel-entry`).
/// Provides:
/// - Vehicle selector with instant telemetry lookup
/// - Vehicle Tank & Mileage Configuration (Capacity, Presets, Fuel Type, Avg Mileage)
/// - 2 Entry Type Tabs: Fuel Refill, Initial Setup
/// - Dynamic Fuel Inputs based on mode
/// - System Odometer auto-filled by default and fully editable
/// - Live distance & fuel consumption calculator
/// - Entry Date & Time picker
/// - Remarks / Notes
/// - Live Telemetry Summary Card (Gauge, Driving Range, Tank Capacity, Mileage)
/// - Recent Entries Audit Trail
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
  String _entryType = 'REFILL'; // 'REFILL' | 'INITIAL'
  bool _isEditingSpecs = false;
  bool _needsConfig = false;

  // Controllers
  final TextEditingController _tankCapacityController = TextEditingController(text: '50');
  String _fuelType = 'Diesel';
  final TextEditingController _mileageController = TextEditingController(text: '16.0');

  final TextEditingController _fuelFilledController = TextEditingController();
  final TextEditingController _currentTankFuelController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  DateTime _entryDateTime = DateTime.now();

  bool _loadingState = false;
  bool _submitting = false;
  Map<String, dynamic>? _fuelState;
  Map<String, dynamic>? _fuelConfig;
  List<Map<String, dynamic>> _historyEntries = <Map<String, dynamic>>[];

  static const List<String> _capacityPresets = <String>[
    '45',
    '60',
    '100',
    '200',
    '300',
    '385',
    '450',
  ];

  static const List<String> _fuelTypes = <String>[
    'Diesel',
    'Petrol',
    'CNG',
  ];

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
        _loadVehicleData(_selectedVehicleId!);
      }
    });
  }

  @override
  void dispose() {
    _tankCapacityController.dispose();
    _mileageController.dispose();
    _fuelFilledController.dispose();
    _currentTankFuelController.dispose();
    _odometerController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Vehicle? _getActiveVehicle() {
    if (_selectedVehicleId == null) return null;
    final List<Vehicle> vehicles = ref.read(fleetProvider).vehicles;
    try {
      return vehicles.firstWhere((v) => v.id == _selectedVehicleId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadVehicleData(String vehicleId) async {
    setState(() => _loadingState = true);
    final FuelService fuelService = ref.read(fuelServiceProvider);

    try {
      final Map<String, dynamic>? state =
          await fuelService.getManualFuelState(vehicleId);
      final Map<String, dynamic>? config =
          await fuelService.getVehicleFuelConfig(vehicleId);
      final List<Map<String, dynamic>> history =
          await fuelService.getManualFuelEntries(vehicleId);

      if (!mounted) return;

      final Vehicle? activeVeh = _getActiveVehicle();

      setState(() {
        _fuelState = state;
        _fuelConfig = config;
        _historyEntries = history;
        _loadingState = false;

        // 1. Vehicle Tank Configuration Sync
        if (config != null) {
          _tankCapacityController.text =
              config['tank_capacity']?.toString() ?? '50';
          _fuelType = config['fuel_type']?.toString() ?? 'Diesel';
          _mileageController.text =
              config['initial_mileage']?.toString() ?? '16.0';
          _needsConfig = false;
          _isEditingSpecs = false;
          _entryType = 'REFILL';
        } else {
          _needsConfig = true;
          _isEditingSpecs = true;
          _entryType = 'INITIAL';
        }

        // 2. ODOMETER AUTO-POPULATION (User Requirement):
        // Automatically default to our system odometer reading, while keeping it editable!
        double sysOdo = 0.0;
        if (activeVeh?.odometer != null && activeVeh!.odometer! > 0) {
          sysOdo = activeVeh.odometer!;
        } else if (state != null && state['last_known_odometer'] != null) {
          sysOdo = double.tryParse(state['last_known_odometer'].toString()) ?? 0.0;
        } else if (config != null && config['initial_odometer'] != null) {
          sysOdo = double.tryParse(config['initial_odometer'].toString()) ?? 0.0;
        } else if (activeVeh?.todayDistanceKm != null && activeVeh!.todayDistanceKm! > 0) {
          sysOdo = activeVeh.todayDistanceKm!;
        }

        if (sysOdo > 0) {
          _odometerController.text = sysOdo % 1 == 0
              ? sysOdo.toInt().toString()
              : sysOdo.toStringAsFixed(2);
        } else {
          _odometerController.text = '';
        }

        // 3. Current Fuel Sync
        if (state != null && state['current_fuel'] != null) {
          final double cur =
              double.tryParse(state['current_fuel'].toString()) ?? 0.0;
          _currentTankFuelController.text =
              (cur % 1 == 0 ? cur.toInt() : (cur * 10).round() / 10).toString();
        } else {
          _currentTankFuelController.text = '';
        }

        _fuelFilledController.clear();
        _remarksController.clear();
        _entryDateTime = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingState = false);
      }
    }
  }

  // Baseline odometer for selected vehicle before user input
  double get _baseOdometer {
    final Vehicle? veh = _getActiveVehicle();
    if (_fuelState != null && _fuelState!['last_known_odometer'] != null) {
      return double.tryParse(_fuelState!['last_known_odometer'].toString()) ?? 0.0;
    }
    if (_fuelConfig != null && _fuelConfig!['initial_odometer'] != null) {
      return double.tryParse(_fuelConfig!['initial_odometer'].toString()) ?? 0.0;
    }
    return veh?.odometer ?? 0.0;
  }

  double get _effectiveTankCapacity {
    final double? parsed = double.tryParse(_tankCapacityController.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    if (_fuelConfig != null && _fuelConfig!['tank_capacity'] != null) {
      return double.tryParse(_fuelConfig!['tank_capacity'].toString()) ?? 50.0;
    }
    return 50.0;
  }

  double get _currentMileage {
    final double? parsed = double.tryParse(_mileageController.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    if (_fuelConfig != null && _fuelConfig!['initial_mileage'] != null) {
      return double.tryParse(_fuelConfig!['initial_mileage'].toString()) ?? 16.0;
    }
    if (_fuelState != null && _fuelState!['current_mileage'] != null) {
      return double.tryParse(_fuelState!['current_mileage'].toString()) ?? 16.0;
    }
    return 16.0;
  }

  double get _incrementalDistance {
    final double inputOdo = double.tryParse(_odometerController.text.trim()) ?? 0.0;
    final double base = _baseOdometer;
    if (inputOdo > base && base > 0) {
      final double diff = (inputOdo - base);
      if (diff > 3000) return 0.0; // abnormal leap indicates odo reset, not a single trip
      return (diff * 10).round() / 10;
    }
    return 0.0;
  }

  double get _incrementalFuelConsumed {
    final double dist = _incrementalDistance;
    final double mil = _currentMileage;
    if (dist > 0 && mil > 0) {
      return (dist / mil * 10).round() / 10;
    }
    return 0.0;
  }

  double get _calculatedNewFuel {
    final double cap = _effectiveTankCapacity;
    final double prevFuel = _fuelState != null && _fuelState!['current_fuel'] != null
        ? (double.tryParse(_fuelState!['current_fuel'].toString()) ?? 0.0)
        : 0.0;
    final double fuelAfterTrip = max(0.0, ((prevFuel - _incrementalFuelConsumed) * 10).round() / 10);

    if (_entryType == 'INITIAL') {
      final double q = double.tryParse(_currentTankFuelController.text.trim()) ?? 0.0;
      return min(q, cap);
    }
    if (_entryType == 'REFILL') {
      final double filled = double.tryParse(_fuelFilledController.text.trim()) ?? 0.0;
      final double? manualTank = double.tryParse(_currentTankFuelController.text.trim());
      if (manualTank != null && manualTank > 0) {
        return min(manualTank, cap);
      }
      return min(cap, ((fuelAfterTrip + filled) * 10).round() / 10);
    }
    return fuelAfterTrip;
  }

  double get _fuelFillPercentage {
    final double cap = _effectiveTankCapacity;
    if (cap <= 0) return 0.0;
    return min(100.0, max(0.0, (_calculatedNewFuel / cap) * 100.0));
  }

  double get _estimatedRange {
    return (_calculatedNewFuel * _currentMileage).roundToDouble();
  }

  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _entryDateTime,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_entryDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _entryDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveSpecsOnly() async {
    final double? cap = double.tryParse(_tankCapacityController.text.trim());
    final double? mil = double.tryParse(_mileageController.text.trim());
    if (cap == null || cap <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid tank capacity in litres')),
      );
      return;
    }
    if (mil == null || mil <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid average mileage (KM/L)')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final FuelService fuelService = ref.read(fuelServiceProvider);
      await fuelService.saveVehicleFuelConfig(
        vehicleId: _selectedVehicleId!,
        fuelType: _fuelType,
        tankCapacity: cap,
        initialFuel: _fuelState != null && _fuelState!['current_fuel'] != null
            ? (double.tryParse(_fuelState!['current_fuel'].toString()) ?? 0.0)
            : 0.0,
        initialOdometer: double.tryParse(_odometerController.text.trim()) ?? _baseOdometer,
        initialMileage: mil,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle tank capacity & specs saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isEditingSpecs = false);
      await _loadVehicleData(_selectedVehicleId!);
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitFuelEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle')),
      );
      return;
    }

    final double cap = _effectiveTankCapacity;
    final double mil = _currentMileage;

    if (_needsConfig || _entryType == 'INITIAL' || _isEditingSpecs) {
      if (cap <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid tank capacity in litres')),
        );
        return;
      }
      if (mil <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter estimated average mileage (KM/L)')),
        );
        return;
      }

      final double initialFuel = double.tryParse(_currentTankFuelController.text.trim()) ?? 0.0;
      if (_entryType == 'INITIAL') {
        if (initialFuel < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter current/initial fuel in tank')),
          );
          return;
        }
        if (initialFuel > cap) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Initial fuel ($initialFuel L) cannot exceed tank capacity ($cap L)'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      try {
        setState(() => _submitting = true);
        final FuelService fuelService = ref.read(fuelServiceProvider);
        await fuelService.saveVehicleFuelConfig(
          vehicleId: _selectedVehicleId!,
          fuelType: _fuelType,
          tankCapacity: cap,
          initialFuel: _entryType == 'INITIAL'
              ? initialFuel
              : (_fuelState != null && _fuelState!['current_fuel'] != null
                  ? (double.tryParse(_fuelState!['current_fuel'].toString()) ?? 0.0)
                  : 0.0),
          initialOdometer: double.tryParse(_odometerController.text.trim()) ?? _baseOdometer,
          initialMileage: mil,
        );
        setState(() {
          _needsConfig = false;
          _isEditingSpecs = false;
        });
      } catch (err) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save config: ${err.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    final double? odo = double.tryParse(_odometerController.text.trim());
    if (odo == null || odo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid odometer reading in KM')),
      );
      return;
    }

    double fuelQty = 0.0;
    double filledQty = 0.0;

    if (_entryType == 'INITIAL') {
      final double? initVal = double.tryParse(_currentTankFuelController.text.trim());
      if (initVal == null || initVal < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter initial fuel currently in tank')),
        );
        return;
      }
      fuelQty = initVal;
      filledQty = initVal;
    } else if (_entryType == 'REFILL') {
      final double? filledVal = double.tryParse(_fuelFilledController.text.trim());
      if (filledVal == null || filledVal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter fuel filled in litres')),
        );
        return;
      }
      if (cap > 0 && filledVal > cap) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fuel filled ($filledVal L) cannot exceed tank capacity ($cap L)'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      filledQty = filledVal;
      final double? curVal = double.tryParse(_currentTankFuelController.text.trim());
      fuelQty = (curVal != null && curVal > 0) ? curVal : _calculatedNewFuel;
    }

    setState(() => _submitting = true);

    try {
      final FuelService fuelService = ref.read(fuelServiceProvider);
      await fuelService.submitManualFuelEntry(
        vehicleId: _selectedVehicleId!,
        entryType: _entryType,
        fuelQuantity: fuelQty,
        fuelFilled: filledQty,
        odometer: odo,
        remarks: _remarksController.text.trim(),
        entryDate: _entryDateTime,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_entryType == 'INITIAL'
              ? 'Initial fuel baseline saved successfully! Switched to Refill mode.'
              : 'Fuel entry recorded successfully! Vehicle telemetry updated.'),
          backgroundColor: Colors.green,
        ),
      );

      _fuelFilledController.clear();
      _remarksController.clear();
      if (_entryType == 'INITIAL') {
        setState(() => _entryType = 'REFILL');
      }

      await _loadVehicleData(_selectedVehicleId!);
      await ref.read(fleetProvider.notifier).load(silent: true);
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Healthy':
        return const Color(0xFF10B981); // Green
      case 'Normal':
        return const Color(0xFF0284C7); // Blue
      case 'Low Fuel':
        return const Color(0xFFD97706); // Amber
      case 'Critical Fuel':
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Vehicle> vehicles = ref.watch(fleetProvider).vehicles;
    final Vehicle? activeVeh = _getActiveVehicle();
    final DateFormat dateDisplayFormat = DateFormat('MM/dd/yyyy hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Sleek clean background
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_gas_station_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Non-Sensor Fuel Entry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  activeVeh?.displayName ?? 'Manual Telematics Portal',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh Telemetry',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              if (_selectedVehicleId != null) {
                _loadVehicleData(_selectedVehicleId!);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Informational Disclaimer Banner ───────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ESTIMATED VALUE SYSTEM: Physical fuel sensors are not installed. Fuel consumed is computed automatically: Fuel Consumed = GPS Distance / Average Mileage.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Vehicle Selector Dropdown Bar ─────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car_filled_rounded, size: 20, color: Color(0xFFEA580C)),
                      const SizedBox(width: 10),
                      const Text(
                        'Vehicle:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedVehicleId,
                            isExpanded: true,
                            hint: const Text('Select Vehicle'),
                            items: vehicles.map((Vehicle v) {
                              return DropdownMenuItem<String>(
                                value: v.id,
                                child: Text(
                                  '${v.displayName} (${v.plate.isNotEmpty ? v.plate : v.name})',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? val) {
                              if (val != null) {
                                setState(() => _selectedVehicleId = val);
                                _loadVehicleData(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Live Telemetry & Fuel Gauge Summary Card ──────────
                if (_loadingState)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFFEA580C)),
                    ),
                  )
                else
                  _buildTelemetrySummaryCard(activeVeh),

                const SizedBox(height: 16),

                // ── 2 Entry Type Tabs: Refill & Initial Setup ────────
                Row(
                  children: [
                    _buildEntryTab(
                      id: 'REFILL',
                      label: 'Fuel Refill',
                      subtext: 'Added fuel to tank',
                      icon: Icons.local_gas_station_rounded,
                    ),
                    const SizedBox(width: 10),
                    _buildEntryTab(
                      id: 'INITIAL',
                      label: 'Initial Setup',
                      subtext: 'Set capacity & baseline',
                      icon: Icons.settings_suggest_rounded,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Vehicle Tank & Mileage Configuration ──────────────
                if (_entryType == 'INITIAL' || _needsConfig || _isEditingSpecs)
                  _buildTankConfigurationCard(),

                if (_entryType == 'INITIAL' || _needsConfig || _isEditingSpecs)
                  const SizedBox(height: 16),

                // ── Main Fuel Entry Form Inputs ───────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subheading
                      Row(
                        children: [
                          Icon(
                            _entryType == 'REFILL'
                                ? Icons.add_circle_outline_rounded
                                : Icons.flag_rounded,
                            size: 18,
                            color: const Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _entryType == 'REFILL'
                                ? 'LOG FUEL REFILL'
                                : 'SET INITIAL FUEL BASELINE',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Refill Inputs
                      if (_entryType == 'REFILL') ...[
                        _buildInputField(
                          label: 'FUEL FILLED (LITRES) *',
                          controller: _fuelFilledController,
                          hintText: 'e.g. 50',
                          prefixIcon: Icons.water_drop_rounded,
                          suffixText: 'Litres',
                          iconColor: const Color(0xFF0284C7),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          helperText: 'Vehicle Tank Capacity: ${_effectiveTankCapacity.toStringAsFixed(0)} Litres',
                          validator: (String? val) {
                            if (val == null || val.trim().isEmpty) return 'Fuel filled is required';
                            final double? v = double.tryParse(val.trim());
                            if (v == null || v <= 0) return 'Must be greater than 0';
                            if (v > _effectiveTankCapacity) {
                              return 'Cannot exceed tank capacity (${_effectiveTankCapacity.toStringAsFixed(0)} L)';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        _buildInputField(
                          label: 'CURRENT TANK LEVEL (OPTIONAL)',
                          controller: _currentTankFuelController,
                          hintText: 'Calculated: ~${_calculatedNewFuel.toStringAsFixed(1)} L',
                          prefixIcon: Icons.speed_rounded,
                          suffixText: 'Litres',
                          iconColor: const Color(0xFF8B5CF6),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          helperText: 'Leave empty to use automatic calculation',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],

                      // Initial Setup Inputs
                      if (_entryType == 'INITIAL') ...[
                        _buildInputField(
                          label: 'INITIAL FUEL CURRENTLY IN TANK (LITRES) *',
                          controller: _currentTankFuelController,
                          hintText: 'e.g. ${(_effectiveTankCapacity * 0.5).toStringAsFixed(1)}',
                          prefixIcon: Icons.speed_rounded,
                          suffixText: 'Litres',
                          iconColor: const Color(0xFFEA580C),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          helperText: 'Cannot exceed tank capacity: ${_effectiveTankCapacity.toStringAsFixed(0)} Litres',
                          validator: (String? val) {
                            if (val == null || val.trim().isEmpty) return 'Fuel quantity is required';
                            final double? v = double.tryParse(val.trim());
                            if (v == null || v < 0) return 'Must be 0 or greater';
                            if (v > _effectiveTankCapacity) {
                              return 'Cannot exceed tank capacity (${_effectiveTankCapacity.toStringAsFixed(0)} L)';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── ODOMETER READING (KM) * ──────────────────────
                      // User requirement: Default to our system odometer & editable
                      _buildInputField(
                        label: 'ODOMETER READING (KM) *',
                        controller: _odometerController,
                        hintText: 'e.g. 440.67',
                        prefixIcon: Icons.trending_up_rounded,
                        suffixText: 'KM',
                        iconColor: const Color(0xFF10B981),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        helperText: 'System Odo auto-loaded. Editable anytime.',
                        validator: (String? val) {
                          if (val == null || val.trim().isEmpty) return 'Odometer reading is required';
                          final double? v = double.tryParse(val.trim());
                          if (v == null || v < 0) return 'Invalid reading';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),

                      // Live Calculation Callout (matching web portal)
                      if (_incrementalDistance > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFED7AA)),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                '+${_incrementalDistance.toStringAsFixed(1)} KM driven',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                              const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                              Text(
                                '-${_incrementalFuelConsumed.toStringAsFixed(1)} L consumed (at ${_currentMileage.toStringAsFixed(1)} km/l)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                              Text(
                                'Est. Remaining: ${_calculatedNewFuel.toStringAsFixed(1)} L',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── ENTRY DATE & TIME ───────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ENTRY DATE & TIME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickDateTime,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      dateDisplayFormat.format(_entryDateTime),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── REMARKS / NOTES (OPTIONAL) ──────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REMARKS / NOTES (OPTIONAL)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _remarksController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Driver notes, bunk name, invoice or receipt details',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── Save Fuel Entry Action Button ─────────────────────
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitFuelEntry,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(
                    _submitting ? 'Saving Fuel Entry...' : 'Save Fuel Entry',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0xFFEA580C).withValues(alpha: 0.4),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Recent Fuel Entries History ───────────────────────
                if (_historyEntries.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      const Text(
                        'Recent Fuel Entries',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_historyEntries.length} entries',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x04000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: min(6, _historyEntries.length),
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> entry = _historyEntries[index];
                        final String type = entry['entry_type']?.toString() ?? 'REFILL';
                        final String qty = entry['fuel_quantity']?.toString() ?? '0';
                        final String time = entry['entry_time']?.toString() ?? '';
                        final String diff = entry['fuel_difference']?.toString() ?? '0';
                        final String odo = entry['odometer']?.toString() ?? '-';
                        final String remarks = entry['remarks']?.toString() ?? '';

                        final Color typeColor = type == 'REFILL'
                            ? const Color(0xFFEA580C)
                            : type == 'INITIAL'
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF0284C7);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: typeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$qty L',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (double.tryParse(diff) != null && double.parse(diff) != 0.0)
                                    Text(
                                      'Diff: ${double.parse(diff) > 0 ? '+' : ''}$diff L',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: double.parse(diff) < 0
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF16A34A),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.speed_rounded, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$odo KM',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                  if (time.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                                    const SizedBox(width: 8),
                                    Text(
                                      time,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                              if (remarks.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  remarks,
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
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

  // ── Helper: Live Telemetry Summary Card ─────────────────────────────
  Widget _buildTelemetrySummaryCard(Vehicle? activeVeh) {
    final double curFuel = _fuelState != null && _fuelState!['current_fuel'] != null
        ? (double.tryParse(_fuelState!['current_fuel'].toString()) ?? 0.0)
        : 0.0;
    final double cap = _effectiveTankCapacity;
    final double percent = cap > 0 ? min(100.0, max(0.0, (curFuel / cap) * 100.0)) : 0.0;
    final String status = _fuelState?['fuel_status']?.toString() ?? 'Normal';
    final Color statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_gas_station_rounded, color: Color(0xFFFB923C), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${curFuel.toStringAsFixed(1)} / ${cap.toStringAsFixed(0)} L',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fuel Level Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent <= 15 ? const Color(0xFFEF4444) : (percent <= 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Estimated Driving Range & Stats Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Driving Range:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '~${_estimatedRange.toStringAsFixed(0)} KM',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Tank Capacity:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cap.toStringAsFixed(0)} Litres',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Average Mileage:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentMileage.toStringAsFixed(1)} km/l',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total GPS Distance:',
                      style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(activeVeh?.odometer ?? _baseOdometer).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFBBF24)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Change Tank Capacity / Mileage Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _isEditingSpecs = !_isEditingSpecs),
              icon: Icon(
                _isEditingSpecs ? Icons.close_rounded : Icons.settings_rounded,
                size: 14,
                color: Colors.white,
              ),
              label: Text(
                _isEditingSpecs ? 'Hide Tank Specifications' : 'Change Tank Capacity / Mileage',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF475569)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: 3 Entry Type Tabs ───────────────────────────────────────
  Widget _buildEntryTab({
    required String id,
    required String label,
    required String subtext,
    required IconData icon,
  }) {
    final bool isSelected = _entryType == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _entryType = id;
            if (id == 'INITIAL') _isEditingSpecs = true;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: Vehicle Tank & Mileage Configuration Card ───────────────
  Widget _buildTankConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: Color(0xFFEA580C)),
                  SizedBox(width: 6),
                  Text(
                    'VEHICLE TANK & MILEAGE CONFIGURATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: Color(0xFF7C2D12),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _needsConfig ? 'Setup Required' : 'Custom Specs',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEA580C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tank Capacity (L) Input
          _buildInputField(
            label: 'TANK CAPACITY (L) *',
            controller: _tankCapacityController,
            hintText: 'e.g. 50, 200, 385',
            prefixIcon: Icons.local_gas_station_rounded,
            suffixText: 'Litres',
            iconColor: const Color(0xFFEA580C),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          // Preset Chips (45L, 60L, 100L, 200L, 300L, 385L, 450L)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _capacityPresets.map((preset) {
              final bool isSelected = _tankCapacityController.text.trim() == preset;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _tankCapacityController.text = preset;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEA580C) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFC2410C) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    '${preset}L',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Fuel Type & Avg Mileage Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fuel Type Dropdown
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FUEL TYPE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _fuelType,
                          isExpanded: true,
                          items: _fuelTypes.map((t) {
                            return DropdownMenuItem<String>(
                              value: t,
                              child: Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? v) {
                            if (v != null) setState(() => _fuelType = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Avg Mileage (KM/L) Input
              Expanded(
                flex: 5,
                child: _buildInputField(
                  label: 'AVG MILEAGE (KM/L) *',
                  controller: _mileageController,
                  hintText: 'e.g. 16.0 or 4.5',
                  prefixIcon: Icons.speed_rounded,
                  suffixText: 'km/l',
                  iconColor: const Color(0xFF059669),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  helperText: 'Truck: 3.5-5 | Car: 12-18',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          if (_isEditingSpecs && !_needsConfig) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _saveSpecsOnly,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Save Tank Specifications', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helper: Generic Input Field ─────────────────────────────────────
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required Color iconColor,
    String? suffixText,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: Icon(prefixIcon, size: 18, color: iconColor),
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 3),
          Text(
            helperText,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
