import 'trip_helpers.dart';

String? formatFlightDateTime(dynamic value) {
  if (value is num && value.isFinite) {
    final d = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return _formatDateTime(d);
  }
  if (value is! String || value.trim().isEmpty) return null;
  final s = value.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
    return formatIsoDateLabel(s);
  }
  final d = DateTime.tryParse(s);
  if (d == null) return s.length > 48 ? '${s.substring(0, 45)}…' : s;
  return _formatDateTime(d);
}

String _formatDateTime(DateTime d) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h = d.hour;
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final min = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year}, $h12:$min $ampm';
}

String? formatFlightDateOnly(dynamic value) {
  if (value is num && value.isFinite) {
    final d = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return formatIsoDateLabel('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }
  if (value is! String || value.trim().isEmpty) return null;
  final s = value.trim();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return formatIsoDateLabel(s);
  final d = DateTime.tryParse(s);
  if (d != null) {
    return formatIsoDateLabel(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }
  return s.length > 48 ? '${s.substring(0, 45)}…' : s;
}

String? formatFlightEndpointFromNested(
    Map<String, dynamic> record, String side,
    [String? Function(dynamic)? fmt]) {
  fmt ??= formatFlightDateTime;
  final v = record[side];
  if (!isObject(v)) return null;
  final nested = pickString(v as Map<String, dynamic>,
      ['at', 'dateTime', 'datetime', 'time', 'localDateTime', 'local_date_time', 'iataDateTime']);
  if (nested != null) return fmt(nested);
  return null;
}

List<Map<String, dynamic>> collectAmadeusSegments(Map<String, dynamic> record) {
  final itineraries = pickArray(record, ['itineraries']) ?? [];
  final out = <Map<String, dynamic>>[];
  for (final it in itineraries) {
    if (!isObject(it)) continue;
    final segs = pickArray(it as Map<String, dynamic>, ['segments']) ?? [];
    for (final s in segs) {
      if (isObject(s)) out.add(s as Map<String, dynamic>);
    }
  }
  return out;
}

String? formatFlightEndpointDisplay(
    Map<String, dynamic> record, String side,
    [bool omitTime = false]) {
  final fmt = omitTime ? formatFlightDateOnly : formatFlightDateTime;
  final nested = formatFlightEndpointFromNested(record, side, fmt);
  if (nested != null) return nested;

  final segs = collectAmadeusSegments(record);
  if (segs.isNotEmpty) {
    final seg = side == 'departure' ? segs.first : segs.last;
    final fromSeg = formatFlightEndpointFromNested(seg, side, fmt);
    if (fromSeg != null) return fromSeg;
  }

  final atKeys = side == 'departure'
      ? ['depart_at', 'departure_at', 'departure_datetime', 'departureDateTime']
      : ['arrive_at', 'arrival_at', 'arrival_datetime', 'arrivalDateTime'];
  final at = pickString(record, atKeys);
  if (at != null) return fmt(at);

  return null;
}

List<Map<String, dynamic>> collectSegmentsFromRecord(Map<String, dynamic> record) {
  final fromAmadeus = collectAmadeusSegments(record);
  if (fromAmadeus.isNotEmpty) return fromAmadeus;
  final direct = pickArray(record, ['segments']) ?? [];
  return direct.whereType<Map<String, dynamic>>().toList();
}

List<List<Map<String, dynamic>>> collectSegmentGroups(Map<String, dynamic> record) {
  final itineraries = pickArray(record, ['itineraries']) ?? [];
  final objs = itineraries.whereType<Map<String, dynamic>>().toList();
  if (objs.length > 1) {
    final groups = objs.map((itin) {
      final segs = pickArray(itin, ['segments']) ?? [];
      return segs.whereType<Map<String, dynamic>>().toList();
    }).where((g) => g.isNotEmpty).toList();
    if (groups.isNotEmpty) return groups;
  }
  final flat = collectSegmentsFromRecord(record);
  return flat.isNotEmpty ? [flat] : [];
}

Map<String, dynamic> gatherFlightOfferSource(Map<String, dynamic> flight) {
  final options = pickArray(flight, ['options']) ?? [];
  final objs = options.whereType<Map<String, dynamic>>().toList();
  return objs.isNotEmpty ? objs.first : flight;
}

String? getSegmentEndpointIata(Map<String, dynamic> seg, String side) {
  final v = seg[side];
  if (!isObject(v)) return null;
  return pickString(v as Map<String, dynamic>, ['iataCode', 'iata']);
}

String resolveFlightHeaderPlaceLabel(
    String? code, TripLocationMaps maps) {
  if (code == null || code.trim().isEmpty) return '';
  final c = code.trim();
  final byCity = maps.cityCodeToName[c];
  if (byCity != null) return byCity;
  final meta = maps.airportToCityMeta[c];
  if (meta != null && meta['cityCode'] != null) {
    final name = maps.cityCodeToName[meta['cityCode']!];
    if (name != null) return name;
    return meta['cityCode']!;
  }
  return c;
}

String formatSegmentCarrier(Map<String, dynamic> seg, Map<String, String>? carriers) {
  final carrier = pickString(seg, ['carrierCode', 'carrier']);
  final n = seg['number'] ?? seg['flight_number'];
  final flightNum = (n is int || (n is double && n.isFinite))
      ? n.toString()
      : (n is String && n.trim().isNotEmpty)
          ? n.trim()
          : pickString(seg, ['number', 'flight_number']);
  if (carrier != null && flightNum != null) {
    final full = carriers?[carrier.trim().toUpperCase()];
    return full != null ? '$carrier $flightNum · $full' : '$carrier $flightNum';
  }
  final airline = pickString(seg, ['airline', 'operatingCarrier']);
  if (airline != null) return flightNum != null ? '$airline $flightNum' : airline;
  return pickString(seg, ['flightNumber']) ?? 'Flight';
}

String? formatSegmentOperatedBy(Map<String, dynamic> seg, Map<String, String>? carriers) {
  final marketing = pickString(seg, ['carrierCode', 'carrier'])?.trim().toUpperCase();
  final opRec = pickRecord(seg, ['operating']);
  final operatingRaw = opRec != null ? pickString(opRec, ['carrierCode', 'carrier']) : null;
  final operating = operatingRaw?.trim().toUpperCase();
  if (marketing == null || operating == null || marketing == operating) return null;
  final name = carriers?[operating] ?? operatingRaw ?? operating;
  return 'Operated by $name';
}

String? formatSegmentDuration(Map<String, dynamic> seg) {
  final dur = pickString(seg, ['duration']);
  if (dur != null) {
    final m = _parseDurationToMinutes(dur);
    if (m != null) return formatDurationMinutesAsHoursMinutes(m);
  }
  final mins = pickNumber(seg, ['duration_minutes', 'durationMinutes']);
  if (mins != null) return formatDurationMinutesAsHoursMinutes(mins);
  return null;
}

int? _parseDurationToMinutes(String value) {
  final t = value.trim();
  final iso = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
      caseSensitive: false).firstMatch(t);
  if (iso != null) {
    final days = int.tryParse(iso.group(1) ?? '') ?? 0;
    final hours = int.tryParse(iso.group(2) ?? '') ?? 0;
    final minutes = int.tryParse(iso.group(3) ?? '') ?? 0;
    final seconds = double.tryParse(iso.group(4) ?? '') ?? 0;
    return (days * 24 * 60 + hours * 60 + minutes + (seconds / 60)).round();
  }
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) {
    final n = double.tryParse(t);
    return n?.round();
  }
  return null;
}

String formatAirportLine(Map<String, dynamic> seg, String side, TripLocationMaps maps) {
  final ep = seg[side];
  if (!isObject(ep)) return '—';
  final epMap = ep as Map<String, dynamic>;
  final iata = pickString(epMap, ['iataCode', 'iata']);
  final terminal = pickString(epMap, ['terminal']);
  final inlineCity = pickString(epMap, ['cityName', 'city']);
  String? cityName;
  if (iata != null && maps.airportToCityMeta.containsKey(iata)) {
    final cityIata = maps.airportToCityMeta[iata]?['cityCode'];
    if (cityIata != null) cityName = maps.cityCodeToName[cityIata];
  }
  cityName ??= inlineCity;
  final parts = <String>[];
  if (iata != null) parts.add(iata);
  if (cityName != null) parts.add(cityName);
  if (terminal != null) parts.add('Terminal $terminal');
  return parts.isNotEmpty ? parts.join(' · ') : '—';
}

String? formatConnectionLayover(Map<String, dynamic> prev, Map<String, dynamic> next) {
  final arr = _parseAtFromSegment(prev, 'arrival');
  final dep = _parseAtFromSegment(next, 'departure');
  if (arr == null || dep == null || dep.isBefore(arr) || dep == arr) return null;
  final mins = dep.difference(arr).inMinutes;
  return formatDurationMinutesAsHoursMinutes(mins);
}

DateTime? _parseAtFromSegment(Map<String, dynamic> seg, String side) {
  final ep = seg[side];
  if (!isObject(ep)) return null;
  final at = pickString(ep as Map<String, dynamic>,
      ['at', 'dateTime', 'localDateTime', 'datetime']);
  if (at == null) return null;
  return DateTime.tryParse(at);
}

({String primary, String? original})? formatAmadeusDualPriceParts(
    Map<String, dynamic> price, String? tripCurrency) {
  final origCur = pickString(price, ['currency']);
  final origAmt = pickScalar(price, ['grandTotal', 'total']);
  final originalLine =
      (origCur != null && origAmt != null) ? '$origAmt $origCur' : null;

  if (tripCurrency != null) {
    final tripAmt = pickScalar(price, [
      'grandTotal_trip_currency', 'total_trip_currency', 'base_trip_currency',
      'grandTotal_itinerary_currency', 'total_itinerary_currency', 'base_itinerary_currency',
    ]);
    if (tripAmt != null) {
      final primary = '$tripAmt $tripCurrency';
      if (originalLine != null && origCur != null && origCur != tripCurrency) {
        return (primary: primary, original: originalLine);
      }
      return (primary: primary, original: null);
    }
  }
  if (originalLine != null) return (primary: originalLine, original: null);
  return null;
}

int? getNightsFromStayForHotel(Map<String, dynamic> stay) {
  final cin = asIsoDate(stay['check_in']) ?? asIsoDate(pickString(stay, ['check_in', 'checkIn']));
  final cout = asIsoDate(stay['check_out']) ?? asIsoDate(pickString(stay, ['check_out', 'checkOut']));
  if (cin == null || cout == null) return null;
  try {
    final d0 = DateTime.parse('${cin}T12:00:00');
    final d1 = DateTime.parse('${cout}T12:00:00');
    final days = d1.difference(d0).inDays;
    return days > 0 ? days : null;
  } catch (_) {
    return null;
  }
}

({String primary, String? original})? formatHotelDualPriceParts(
    Map<String, dynamic> opt, String? tripCurrency,
    [Map<String, dynamic>? parentStay]) {
  int? nights;
  if (parentStay != null) nights = getNightsFromStayForHotel(parentStay);
  nights ??= getNightsFromStayForHotel(opt);
  final nightsLabel = nights != null
      ? ' / $nights ${nights == 1 ? "night" : "nights"}'
      : '';

  final r = isObject(opt['_ranking'])
      ? opt['_ranking'] as Map<String, dynamic>
      : null;
  final offers = pickArray(opt, ['offers']) ?? [];
  final first = offers.whereType<Map<String, dynamic>>().firstOrNull;
  final price = first != null ? pickRecord(first, ['price']) : null;
  final origCur = price != null ? pickString(price, ['currency']) : null;
  final origTotal = price != null ? pickScalar(price, ['grandTotal', 'total']) : null;

  if (tripCurrency != null) {
    if (price != null) {
      final tripAmt = pickScalar(price, [
        'total_trip_currency', 'grandTotal_trip_currency',
        'total_itinerary_currency', 'grandTotal_itinerary_currency',
      ]);
      if (tripAmt != null) {
        final primary = '$tripAmt $tripCurrency$nightsLabel';
        if (origTotal != null && origCur != null && origCur != tripCurrency) {
          return (primary: primary, original: '$origTotal $origCur$nightsLabel');
        }
        return (primary: primary, original: null);
      }
    }
    if (r != null) {
      final fromR = pickScalar(r, [
        'total_trip_currency', 'total_stay_trip_currency', 'grand_total_trip_currency',
        'total_itinerary_currency', 'total_stay_itinerary_currency', 'grand_total_itinerary_currency',
      ]);
      if (fromR != null) {
        return (primary: '$fromR $tripCurrency$nightsLabel', original: null);
      }
      final pn = pickScalar(r, [
        'price_per_night_trip_currency', 'price_per_night_itinerary_currency'
      ]);
      if (pn != null && nights != null) {
        final pnAmt = parseFiniteAmount(pn);
        if (pnAmt != null) {
          return (
            primary: '${formatSummaryAmount(pnAmt * nights)} $tripCurrency$nightsLabel',
            original: null,
          );
        }
      }
    }
  }

  if (price != null && origTotal != null && origCur != null) {
    return (primary: '$origTotal $origCur$nightsLabel', original: null);
  }
  return null;
}

String toTitleCaseWords(String s) {
  return s.trim().toLowerCase().split(RegExp(r'[\s_]+')).where((w) => w.isNotEmpty).map((w) {
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}

String? pickFlightOptionRouteFrom(
    Map<String, dynamic> opt, Map<String, dynamic> parentFlight) {
  final flat = collectSegmentsFromRecord(opt);
  if (flat.isNotEmpty) return getSegmentEndpointIata(flat.first, 'departure');
  return pickString(opt, ['from', 'origin']) ??
      pickString(parentFlight, ['from', 'origin']);
}

String? pickFlightOptionRouteTo(
    Map<String, dynamic> opt, Map<String, dynamic> parentFlight) {
  final flat = collectSegmentsFromRecord(opt);
  if (flat.isNotEmpty) return getSegmentEndpointIata(flat.last, 'arrival');
  return pickString(opt, ['to', 'destination']) ??
      pickString(parentFlight, ['to', 'destination']);
}
