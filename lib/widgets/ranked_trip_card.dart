import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/trip_helpers.dart';
import '../utils/trip_ranked_model.dart';
import 'dual_price_display.dart';
import 'trip_flights.dart';
import 'trip_hotels.dart';

class RankedTripCard extends StatefulWidget {
  final Map<String, dynamic> envelope;
  final Map<String, dynamic> ranked;
  final bool detailed;
  /// When true (e.g. full-screen modal), trip chrome uses 100% opacity instead of chat translucency.
  final bool opaqueLayers;

  const RankedTripCard({
    super.key,
    required this.envelope,
    required this.ranked,
    this.detailed = false,
    this.opaqueLayers = false,
  });

  @override
  State<RankedTripCard> createState() => _RankedTripCardState();
}

class _RankedTripCardState extends State<RankedTripCard> {
  late Map<String, dynamic> _rankedState;
  late TripLocationMaps _locationMaps;
  late Map<String, String> _carrierMap;
  late String? _tripCurrency;

  @override
  void initState() {
    super.initState();
    _rankedState = deepCloneMap(widget.ranked);
    sortFlightAndHotelOptionsByRankingInRanked(_rankedState);
    recomputeSummaryTotalsFromRanked(_rankedState);
    _locationMaps = extractTripLocationMaps(_rankedState);
    _carrierMap = {
      ...extractFlightCarriersMap(widget.envelope),
      ...extractFlightCarriersMap(_rankedState),
    };
    final summary = pickRecord(_rankedState, ['summary']);
    _tripCurrency = summary != null
        ? pickString(summary, ['trip_currency', 'itinerary_currency'])
        : null;
  }

  void _reorderFlightOptions(int legIndex, int flightIndex, List<dynamic> newOptions) {
    setState(() {
      _rankedState = deepCloneMap(_rankedState);
      applyFlightOptionsReorder(_rankedState, legIndex, flightIndex, newOptions);
      recomputeSummaryTotalsFromRanked(_rankedState);
    });
  }

  void _reorderHotelOptions(int legIndex, int hotelIndex, List<dynamic> newOptions) {
    setState(() {
      _rankedState = deepCloneMap(_rankedState);
      applyHotelOptionsReorder(_rankedState, legIndex, hotelIndex, newOptions);
      recomputeSummaryTotalsFromRanked(_rankedState);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripIndex = pickNumber(widget.envelope, ['trip_index', 'itinerary_index']);
    final tripCount = pickNumber(widget.envelope, ['trip_count', 'itinerary_count']);
    final summary = pickRecord(_rankedState, ['summary']);
    final totalDays = summary != null ? pickNumber(summary, ['total_duration_days']) : null;
    final tripStartIso = summary != null
        ? asIsoDate(pickString(summary, ['trip_start_date', 'itinerary_start_date', 'start_date', 'startDate']))
        : null;
    final tripEndIso = summary != null
        ? asIsoDate(pickString(summary, ['trip_end_date', 'itinerary_end_date', 'end_date', 'endDate']))
        : null;
    final hasHotels = rankedTripHasHotelOptions(_rankedState);

    final totals = computeFlightHotelTripTotalsFromRanked(_rankedState);
    final flightsParts = computedFlightHotelSummaryParts(
        totals.flightsTripSum, totals.flightsContributions, _tripCurrency);
    final hotelsParts = hasHotels
        ? computedFlightHotelSummaryParts(
            totals.hotelsTripSum, totals.hotelsContributions, _tripCurrency)
        : null;

    final legs = getLegsFromRanked(_rankedState);
    final legsWithContent = legs.where((leg) {
      final f = pickArray(leg, ['flights']) ?? [];
      final h = pickArray(leg, ['hotels']) ?? [];
      return f.isNotEmpty || h.isNotEmpty;
    }).toList();

    final layers = TripLayers.of(widget.opaqueLayers);

    return TripDataProvider(
      tripCurrency: _tripCurrency,
      locationMaps: _locationMaps,
      carrierMap: _carrierMap,
      opaqueLayers: widget.opaqueLayers,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: layers.surface,
          border: Border.all(color: layers.border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip${tripIndex != null && tripCount != null ? ' • ${tripIndex.toInt() + 1}/${tripCount.toInt()}' : ''}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
            ),
            if (tripStartIso != null || flightsParts != null || hotelsParts != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryTile(
                    layers: layers,
                    label: 'Dates',
                    child: Text(
                      formatTripSummaryDates(tripStartIso, tripEndIso, totalDays),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground),
                    ),
                  ),
                  _SummaryTile(
                    layers: layers,
                    label: 'Flights',
                    child: flightsParts != null
                        ? DualPriceDisplay(primary: flightsParts.primary, original: flightsParts.original)
                        : const Text('—', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                  ),
                  if (hasHotels)
                    _SummaryTile(
                      layers: layers,
                      label: 'Hotels',
                      child: hotelsParts != null
                          ? DualPriceDisplay(primary: hotelsParts.primary, original: hotelsParts.original)
                          : const Text('—', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                    ),
                ],
              ),
            ],
            if (legsWithContent.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...legsWithContent.asMap().entries.map((entry) {
                final legIdx = entry.key;
                final leg = entry.value;
                final legFlights = pickArray(leg, ['flights']) ?? [];
                final legHotels = pickArray(leg, ['hotels']) ?? [];
                final legLabel = pickString(leg, ['title', 'name', 'label']) ??
                    pickString(leg, ['from', 'origin']) ??
                    (legsWithContent.length > 1 ? 'Leg ${legIdx + 1}' : null);
                final legStartRaw = asIsoDate(pickString(leg, ['start_date', 'startDate']));
                final legEndRaw = asIsoDate(pickString(leg, ['end_date', 'endDate']));
                final legDates = [
                  legStartRaw != null ? formatIsoDateLabel(legStartRaw) : null,
                  legEndRaw != null ? formatIsoDateLabel(legEndRaw) : null,
                ].where((s) => s != null).join(' → ');

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: layers.background,
                    border: Border.all(color: layers.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (legLabel != null || legDates.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (legLabel != null)
                              Flexible(
                                child: Text(legLabel,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                              ),
                            if (legDates.isNotEmpty)
                              Text(legDates, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      LegFlightsBlock(
                        flights: legFlights,
                        legIndex: legIdx,
                        showChevrons: widget.detailed,
                        onReorderOptions: (flightIndex, newOptions) =>
                            _reorderFlightOptions(legIdx, flightIndex, newOptions),
                      ),
                      if (legFlights.isNotEmpty && legHotels.isNotEmpty) const SizedBox(height: 16),
                      LegHotelsBlock(
                        hotels: legHotels,
                        legIndex: legIdx,
                        showChevrons: widget.detailed,
                        onReorderOptions: (hotelIndex, newOptions) =>
                            _reorderHotelOptions(legIdx, hotelIndex, newOptions),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final TripLayers layers;
  final String label;
  final Widget child;
  const _SummaryTile({required this.layers, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: layers.background,
        border: Border.all(color: layers.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class TripDataProvider extends InheritedWidget {
  final String? tripCurrency;
  final TripLocationMaps locationMaps;
  final Map<String, String> carrierMap;
  final bool opaqueLayers;

  const TripDataProvider({
    super.key,
    required this.tripCurrency,
    required this.locationMaps,
    required this.carrierMap,
    this.opaqueLayers = false,
    required super.child,
  });

  static TripDataProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TripDataProvider>();
  }

  @override
  bool updateShouldNotify(TripDataProvider oldWidget) =>
      tripCurrency != oldWidget.tripCurrency ||
      locationMaps != oldWidget.locationMaps ||
      carrierMap != oldWidget.carrierMap ||
      opaqueLayers != oldWidget.opaqueLayers;
}
