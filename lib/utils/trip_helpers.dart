typedef UnknownRecord = Map<String, dynamic>;

bool isObject(dynamic value) =>
    value is Map<String, dynamic>;

String? pickString(Map<String, dynamic> obj, List<String> keys) {
  for (final k in keys) {
    final v = obj[k];
    if (v is String && v.trim().isNotEmpty) return v;
  }
  return null;
}

List<dynamic>? pickArray(Map<String, dynamic> obj, List<String> keys) {
  for (final k in keys) {
    final v = obj[k];
    if (v is List) return v;
  }
  return null;
}

num? pickNumber(Map<String, dynamic> obj, List<String> keys) {
  for (final k in keys) {
    final v = obj[k];
    if (v is num && v.isFinite) return v;
  }
  return null;
}

String? pickScalar(Map<String, dynamic> obj, List<String> keys) {
  for (final k in keys) {
    final v = obj[k];
    if (v is num && v.isFinite) return v.toString();
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

Map<String, dynamic>? pickRecord(Map<String, dynamic> obj, List<String> keys) {
  for (final k in keys) {
    final v = obj[k];
    if (isObject(v)) return v as Map<String, dynamic>;
  }
  return null;
}

String? asIsoDate(dynamic value) {
  return (value is String && value.length >= 10) ? value.substring(0, 10) : null;
}

String formatDurationMinutesAsHoursMinutes(num totalMinutes) {
  if (!totalMinutes.isFinite || totalMinutes < 0) return '';
  final rounded = totalMinutes.round();
  final hours = rounded ~/ 60;
  final minutes = rounded % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String formatIsoDateLabel(String isoDate) {
  final parts = isoDate.split('-').map(int.tryParse).toList();
  if (parts.length < 3 || parts.any((e) => e == null)) return isoDate;
  final d = DateTime(parts[0]!, parts[1]!, parts[2]!);
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String formatTripSummaryDates(
    String? startIso, String? endIso, num? totalDurationDays) {
  if (startIso != null && endIso != null) {
    return '${formatIsoDateLabel(startIso)} → ${formatIsoDateLabel(endIso)}';
  }
  if (startIso != null) return '${formatIsoDateLabel(startIso)} → —';
  if (endIso != null) return '— → ${formatIsoDateLabel(endIso)}';
  if (totalDurationDays != null) return '$totalDurationDays days';
  return '—';
}

String formatHotelCityLine(
    String? cityCode, Map<String, String> cityCodeToName) {
  if (cityCode == null || cityCode.trim().isEmpty) return '';
  final code = cityCode.trim();
  return cityCodeToName[code] ?? code;
}

class TripLocationMaps {
  final Map<String, Map<String, String?>> airportToCityMeta;
  final Map<String, String> cityCodeToName;
  const TripLocationMaps({
    this.airportToCityMeta = const {},
    this.cityCodeToName = const {},
  });
}

TripLocationMaps extractTripLocationMaps(Map<String, dynamic> ranked) {
  final cityCodeToName = <String, String>{};
  final locDict = pickRecord(ranked, ['locations_dictionary']);
  if (locDict != null) {
    for (final e in locDict.entries) {
      if (e.value is String && (e.value as String).trim().isNotEmpty) {
        cityCodeToName[e.key] = (e.value as String).trim();
      }
    }
  }

  final airportToCityMeta = <String, Map<String, String?>>{};
  void mergeAirportMap(Map<String, dynamic>? m) {
    if (m == null) return;
    for (final e in m.entries) {
      if (!isObject(e.value)) continue;
      final o = e.value as Map<String, dynamic>;
      airportToCityMeta[e.key] = {
        'cityCode': pickString(o, ['cityCode', 'city_code']),
        'countryCode': pickString(o, ['countryCode', 'country_code']),
      };
    }
  }

  final fd = pickRecord(ranked, ['flight_dictionaries']);
  final locFromFlight = fd != null ? pickRecord(fd, ['locations']) : null;
  mergeAirportMap(locFromFlight);
  if (airportToCityMeta.isEmpty) {
    mergeAirportMap(pickRecord(ranked, ['airport_dictionaries']));
  }

  return TripLocationMaps(
    airportToCityMeta: airportToCityMeta,
    cityCodeToName: cityCodeToName,
  );
}

Map<String, String> extractFlightCarriersMap(Map<String, dynamic> ranked) {
  final out = <String, String>{};
  final fd = pickRecord(ranked, ['flight_dictionaries']);
  final carriers = fd != null ? pickRecord(fd, ['carriers']) : null;
  if (carriers == null) return out;
  for (final e in carriers.entries) {
    if (e.value is! String || (e.value as String).trim().isEmpty) continue;
    out[e.key.trim().toUpperCase()] = (e.value as String).trim();
  }
  return out;
}

double? parseFiniteAmount(String s) {
  final n = double.tryParse(s);
  return (n != null && n.isFinite) ? n : null;
}

String formatSummaryAmount(double n) {
  if (!n.isFinite) return '0';
  return n.toStringAsFixed(2);
}
