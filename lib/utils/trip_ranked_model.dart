import 'trip_helpers.dart';

List<Map<String, dynamic>> getLegsFromRanked(Map<String, dynamic> ranked) {
  final legs = pickArray(ranked,
      ['legs', 'trip_legs', 'itinerary_legs', 'segments', 'trip_segments']);
  if (legs != null && legs.isNotEmpty) {
    return legs.whereType<Map<String, dynamic>>().toList();
  }
  final flights = pickArray(ranked, ['flights']) ?? [];
  final hotels = pickArray(ranked, ['hotels']) ?? [];
  if (flights.isEmpty && hotels.isEmpty) return [];
  return [
    <String, dynamic>{'flights': flights, 'hotels': hotels}
  ];
}

bool rankedTripHasHotelOptions(Map<String, dynamic> ranked) {
  for (final leg in getLegsFromRanked(ranked)) {
    final hotels = pickArray(leg, ['hotels']) ?? [];
    for (final h in hotels) {
      if (!isObject(h)) continue;
      final opts = pickArray(h as Map<String, dynamic>, ['options']) ?? [];
      if (opts.any(isObject)) return true;
    }
  }
  return false;
}

double? _getFlightOptionTripAmount(Map<String, dynamic> opt) {
  final price = pickRecord(opt, ['price']);
  if (price == null) return null;
  final v = pickScalar(price, [
    'grandTotal_trip_currency',
    'total_trip_currency',
    'base_trip_currency',
    'grandTotal_itinerary_currency',
    'total_itinerary_currency',
    'base_itinerary_currency',
  ]);
  return v != null ? parseFiniteAmount(v) : null;
}

double? _getFlightLegContribution(Map<String, dynamic> flight) {
  final options = pickArray(flight, ['options']) ?? [];
  final objs = options.where(isObject).cast<Map<String, dynamic>>().toList();
  if (objs.isNotEmpty) {
    final fromOpt = _getFlightOptionTripAmount(objs.first);
    if (fromOpt != null) return fromOpt;
  }
  final price = pickRecord(flight, ['price']);
  if (price != null) {
    final v = pickScalar(price, [
      'grandTotal_trip_currency',
      'total_trip_currency',
      'base_trip_currency',
      'grandTotal_itinerary_currency',
      'total_itinerary_currency',
      'base_itinerary_currency',
    ]);
    if (v != null) return parseFiniteAmount(v);
  }
  return null;
}

int? _getNightsFromStay(Map<String, dynamic> stay) {
  final cin =
      asIsoDate(stay['check_in']) ?? asIsoDate(pickString(stay, ['check_in', 'checkIn']));
  final cout =
      asIsoDate(stay['check_out']) ?? asIsoDate(pickString(stay, ['check_out', 'checkOut']));
  if (cin == null || cout == null) return null;
  final d0 = DateTime.parse('${cin}T12:00:00');
  final d1 = DateTime.parse('${cout}T12:00:00');
  final days = d1.difference(d0).inDays;
  return days > 0 ? days : null;
}

double? _getHotelOptionTripTotal(
    Map<String, dynamic> opt, Map<String, dynamic> parentStay) {
  final r = isObject(opt['_ranking'])
      ? opt['_ranking'] as Map<String, dynamic>
      : null;
  if (r != null) {
    final total = pickScalar(r, [
      'total_trip_currency', 'total_stay_trip_currency',
      'grand_total_trip_currency',
      'total_itinerary_currency', 'total_stay_itinerary_currency',
      'grand_total_itinerary_currency',
    ]);
    if (total != null) return parseFiniteAmount(total);
    final pn = pickScalar(
        r, ['price_per_night_trip_currency', 'price_per_night_itinerary_currency']);
    final nights = _getNightsFromStay(parentStay);
    final pnAmt = pn != null ? parseFiniteAmount(pn) : null;
    if (pnAmt != null && nights != null) return pnAmt * nights;
  }
  final offers = pickArray(opt, ['offers']) ?? [];
  final first = offers.whereType<Map<String, dynamic>>().firstOrNull;
  final price = first != null ? pickRecord(first, ['price']) : null;
  if (price != null) {
    final v = pickScalar(price, [
      'total_trip_currency', 'grandTotal_trip_currency',
      'total_itinerary_currency', 'grandTotal_itinerary_currency',
    ]);
    if (v != null) return parseFiniteAmount(v);
  }
  return null;
}

double? _getHotelLegContribution(Map<String, dynamic> stay) {
  final options = pickArray(stay, ['options']) ?? [];
  final objs = options.where(isObject).cast<Map<String, dynamic>>().toList();
  if (objs.isNotEmpty) return _getHotelOptionTripTotal(objs.first, stay);
  return null;
}

({double flightsTripSum, int flightsContributions, double hotelsTripSum, int hotelsContributions})
    computeFlightHotelTripTotalsFromRanked(Map<String, dynamic> ranked) {
  final legs = getLegsFromRanked(ranked);
  double flightsSum = 0, hotelsSum = 0;
  int flightsC = 0, hotelsC = 0;

  for (final leg in legs) {
    for (final f in (pickArray(leg, ['flights']) ?? [])) {
      if (!isObject(f)) continue;
      final amt = _getFlightLegContribution(f as Map<String, dynamic>);
      if (amt != null) {
        flightsSum += amt;
        flightsC++;
      }
    }
    for (final h in (pickArray(leg, ['hotels']) ?? [])) {
      if (!isObject(h)) continue;
      final amt = _getHotelLegContribution(h as Map<String, dynamic>);
      if (amt != null) {
        hotelsSum += amt;
        hotelsC++;
      }
    }
  }

  return (
    flightsTripSum: flightsSum,
    flightsContributions: flightsC,
    hotelsTripSum: hotelsSum,
    hotelsContributions: hotelsC,
  );
}

void recomputeSummaryTotalsFromRanked(Map<String, dynamic> ranked) {
  final summary = pickRecord(ranked, ['summary']);
  if (summary == null) return;
  final t = computeFlightHotelTripTotalsFromRanked(ranked);
  if (t.flightsContributions > 0) {
    final f = formatSummaryAmount(t.flightsTripSum);
    summary['total_flights_cost_itinerary_currency'] = f;
    summary['total_flights_cost_trip_currency'] = f;
  }
  if (t.hotelsContributions > 0) {
    final h = formatSummaryAmount(t.hotelsTripSum);
    summary['total_hotels_cost_itinerary_currency'] = h;
    summary['total_hotels_cost_trip_currency'] = h;
  }
}

({String primary, String? original})? computedFlightHotelSummaryParts(
    double sum, int contributions, String? tripCurrency) {
  if (contributions <= 0) return null;
  final amt = formatSummaryAmount(sum);
  if (tripCurrency != null) return (primary: '$amt $tripCurrency', original: null);
  return (primary: amt, original: null);
}

double? _pickOptionRankingScore(Map<String, dynamic> opt) {
  final r =
      isObject(opt['_ranking']) ? opt['_ranking'] as Map<String, dynamic> : null;
  if (r == null) return null;
  final s = r['score'];
  if (s is num && s.isFinite) return s.toDouble();
  if (s is String && s.trim().isNotEmpty) {
    final n = double.tryParse(s.trim());
    if (n != null && n.isFinite) return n;
  }
  return null;
}

List<dynamic> _sortOptionsByRankingScore(List<dynamic> objs) {
  final sorted = List<dynamic>.from(objs);
  sorted.sort((a, b) {
    if (!isObject(a) || !isObject(b)) return 0;
    final sa = _pickOptionRankingScore(a as Map<String, dynamic>);
    final sb = _pickOptionRankingScore(b as Map<String, dynamic>);
    if (sa != null && sb != null) return sb.compareTo(sa);
    if (sa != null) return -1;
    if (sb != null) return 1;
    return 0;
  });
  return sorted;
}

void _sortOptionsOnEntity(Map<String, dynamic> entity) {
  final options = pickArray(entity, ['options']) ?? [];
  final objs = options.where(isObject).toList();
  if (objs.length < 2) return;
  entity['options'] = _sortOptionsByRankingScore(objs);
}

void sortFlightAndHotelOptionsByRankingInRanked(Map<String, dynamic> ranked) {
  final legs = pickArray(ranked,
      ['legs', 'trip_legs', 'itinerary_legs', 'segments', 'trip_segments']);
  if (legs != null && legs.isNotEmpty) {
    for (final leg in legs) {
      if (!isObject(leg)) continue;
      final m = leg as Map<String, dynamic>;
      for (final f in (pickArray(m, ['flights']) ?? [])) {
        if (isObject(f)) _sortOptionsOnEntity(f as Map<String, dynamic>);
      }
      for (final h in (pickArray(m, ['hotels']) ?? [])) {
        if (isObject(h)) _sortOptionsOnEntity(h as Map<String, dynamic>);
      }
    }
    return;
  }
  for (final f in (pickArray(ranked, ['flights']) ?? [])) {
    if (isObject(f)) _sortOptionsOnEntity(f as Map<String, dynamic>);
  }
  for (final h in (pickArray(ranked, ['hotels']) ?? [])) {
    if (isObject(h)) _sortOptionsOnEntity(h as Map<String, dynamic>);
  }
}

void applyFlightOptionsReorder(
    Map<String, dynamic> ranked, int legIndex, int flightIndex,
    List<dynamic> newOptions) {
  final legs = pickArray(ranked,
      ['legs', 'trip_legs', 'itinerary_legs', 'segments', 'trip_segments']);
  if (legs != null && legs.isNotEmpty) {
    final leg = legs[legIndex];
    if (isObject(leg)) {
      final flights = pickArray(leg as Map<String, dynamic>, ['flights']) ?? [];
      final target = flights[flightIndex];
      if (isObject(target)) {
        (target as Map<String, dynamic>)['options'] = newOptions;
      }
    }
    return;
  }
  final flights = pickArray(ranked, ['flights']) ?? [];
  final target = flights[flightIndex];
  if (isObject(target)) {
    (target as Map<String, dynamic>)['options'] = newOptions;
  }
}

void applyHotelOptionsReorder(
    Map<String, dynamic> ranked, int legIndex, int hotelIndex,
    List<dynamic> newOptions) {
  final legs = pickArray(ranked,
      ['legs', 'trip_legs', 'itinerary_legs', 'segments', 'trip_segments']);
  if (legs != null && legs.isNotEmpty) {
    final leg = legs[legIndex];
    if (isObject(leg)) {
      final hotels = pickArray(leg as Map<String, dynamic>, ['hotels']) ?? [];
      final target = hotels[hotelIndex];
      if (isObject(target)) {
        (target as Map<String, dynamic>)['options'] = newOptions;
      }
    }
    return;
  }
  final hotels = pickArray(ranked, ['hotels']) ?? [];
  final target = hotels[hotelIndex];
  if (isObject(target)) {
    (target as Map<String, dynamic>)['options'] = newOptions;
  }
}

Map<String, dynamic> deepCloneMap(Map<String, dynamic> src) {
  return _deepClone(src) as Map<String, dynamic>;
}

dynamic _deepClone(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, _deepClone(v)));
  }
  if (value is List) {
    return value.map(_deepClone).toList();
  }
  return value;
}
