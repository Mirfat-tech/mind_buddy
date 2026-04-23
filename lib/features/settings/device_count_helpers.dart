int countDistinctDeviceIds(Iterable<dynamic> rows) {
  final deviceIds = <String>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final rawId = row['device_id'];
    final deviceId = rawId?.toString().trim() ?? '';
    if (deviceId.isEmpty) continue;
    deviceIds.add(deviceId);
  }
  return deviceIds.length;
}
