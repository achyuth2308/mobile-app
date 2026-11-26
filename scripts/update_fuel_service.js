const fs = require('fs');
const path = require('path');

const targetFile = path.join(__dirname, '../lib/features/fuel/services/fuel_service.dart');
let content = fs.readFileSync(targetFile, 'utf8');

if (!content.includes('submitManualFuelEntry')) {
  const addition = `
  Future<Map<String, dynamic>?> getManualFuelState(String vehicleId) async {
    try {
      final Response<dynamic> response =
          await _apiClient.get('/api/fuel/manual/state/$vehicleId');
      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('[FUEL] getManualFuelState error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> submitManualFuelEntry({
    required String vehicleId,
    required String entryType,
    required double fuelQuantity,
    double fuelFilled = 0.0,
    required double odometer,
    String? remarks,
  }) async {
    final Response<dynamic> response = await _apiClient.post(
      '/api/fuel/manual/entry/$vehicleId',
      data: <String, dynamic>{
        'entryType': entryType,
        'fuelQuantity': fuelQuantity,
        'fuelFilled': fuelFilled,
        'odometer': odometer,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
    if (response.data is Map && response.data['success'] == true) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception(response.data['error'] ?? 'Failed to submit fuel entry');
  }

  Future<List<Map<String, dynamic>>> getManualFuelEntries(String vehicleId) async {
    try {
      final Response<dynamic> response =
          await _apiClient.get('/api/fuel/manual/entries/$vehicleId');
      if (response.data is Map && response.data['success'] == true) {
        final dynamic data = response.data['data'];
        if (data is Map && data['entries'] is List) {
          return (data['entries'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('[FUEL] getManualFuelEntries error: $e');
    }
    return <Map<String, dynamic>>[];
  }
}
`;

  content = content.replace(/\}\s*$/, addition);
  fs.writeFileSync(targetFile, content, 'utf8');
  console.log('SUCCESS: fuel_service.dart updated.');
} else {
  console.log('ALREADY INCLUDED.');
}
