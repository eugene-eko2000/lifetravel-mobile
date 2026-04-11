import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/trip_helpers.dart';
import '../utils/trip_formatting.dart';
import 'dual_price_display.dart';
import 'ranked_trip_card.dart';

class LegFlightsBlock extends StatelessWidget {
  final List<dynamic> flights;
  final int legIndex;
  final bool showChevrons;
  final void Function(int flightIndex, List<dynamic> newOptions)? onReorderOptions;

  const LegFlightsBlock({
    super.key,
    required this.flights,
    required this.legIndex,
    this.showChevrons = false,
    this.onReorderOptions,
  });

  @override
  Widget build(BuildContext context) {
    final list = flights.whereType<Map<String, dynamic>>().toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Flights',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
        const SizedBox(height: 8),
        ...list.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FlightRow(
                flight: e.value,
                labelIndex: e.key,
                legIndex: legIndex,
                showChevrons: showChevrons,
                onOptionsReorder: onReorderOptions != null
                    ? (newOptions) => onReorderOptions!(e.key, newOptions)
                    : null,
              ),
            )),
      ],
    );
  }
}

class _FlightRow extends StatefulWidget {
  final Map<String, dynamic> flight;
  final int labelIndex;
  final int legIndex;
  final bool showChevrons;
  final void Function(List<dynamic> newOptions)? onOptionsReorder;

  const _FlightRow({
    required this.flight,
    required this.labelIndex,
    required this.legIndex,
    this.showChevrons = false,
    this.onOptionsReorder,
  });

  @override
  State<_FlightRow> createState() => _FlightRowState();
}

class _FlightRowState extends State<_FlightRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = TripDataProvider.of(context);
    final maps = provider?.locationMaps ?? const TripLocationMaps();
    final from = pickString(widget.flight, ['from']);
    final to = pickString(widget.flight, ['to']);
    final options = pickArray(widget.flight, ['options']) ?? [];
    final objectOptions = options.whereType<Map<String, dynamic>>().toList();

    final title = [
      resolveFlightHeaderPlaceLabel(from, maps),
      resolveFlightHeaderPlaceLabel(to, maps),
    ].where((s) => s.isNotEmpty).join(' → ');
    final displayTitle = title.isNotEmpty ? title : 'Flight ${widget.labelIndex + 1}';

    final dep = formatFlightEndpointDisplay(widget.flight, 'departure', true);
    final arr = formatFlightEndpointDisplay(widget.flight, 'arrival', true);
    final dateSummary = [dep, arr].where((s) => s != null).join(' → ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withAlpha(100),
        border: Border.all(color: AppColors.border.withAlpha(200)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (widget.showChevrons)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(_expanded ? '▼' : '▶',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(displayTitle,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                            ),
                            if (dateSummary.isNotEmpty)
                              Text(dateSummary, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        if (objectOptions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              objectOptions.length == 1 ? '1 fare option' : '${objectOptions.length} fare options',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && objectOptions.isNotEmpty) ...[
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: Color(0x19171717),
              ),
              padding: const EdgeInsets.all(10),
              child: _buildOptionsList(objectOptions),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionsList(List<Map<String, dynamic>> objectOptions) {
    if (objectOptions.length > 1 && widget.onOptionsReorder != null) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: objectOptions.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          final item = objectOptions.removeAt(oldIndex);
          objectOptions.insert(newIndex, item);
          widget.onOptionsReorder!(List<dynamic>.from(objectOptions));
        },
        itemBuilder: (context, i) => Padding(
          key: ValueKey('flight-opt-${widget.legIndex}-${widget.labelIndex}-$i-${objectOptions[i].hashCode}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _FlightOptionBox(
            opt: objectOptions[i],
            optionIndex: i,
            parentFlight: widget.flight,
            showChevrons: widget.showChevrons,
          ),
        ),
      );
    }
    return Column(
      children: objectOptions.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FlightOptionBox(
              opt: e.value,
              optionIndex: e.key,
              parentFlight: widget.flight,
              showChevrons: widget.showChevrons,
            ),
          )).toList(),
    );
  }
}

class _FlightOptionBox extends StatefulWidget {
  final Map<String, dynamic> opt;
  final int optionIndex;
  final Map<String, dynamic> parentFlight;
  final bool showChevrons;

  const _FlightOptionBox({
    required this.opt,
    required this.optionIndex,
    required this.parentFlight,
    this.showChevrons = false,
  });

  @override
  State<_FlightOptionBox> createState() => _FlightOptionBoxState();
}

class _FlightOptionBoxState extends State<_FlightOptionBox> {
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final provider = TripDataProvider.of(context);
    final tripCurrency = provider?.tripCurrency;
    final maps = provider?.locationMaps ?? const TripLocationMaps();
    final carriers = provider?.carrierMap ?? {};
    final isTop = widget.optionIndex == 0;

    final routeFrom = pickFlightOptionRouteFrom(widget.opt, widget.parentFlight);
    final routeTo = pickFlightOptionRouteTo(widget.opt, widget.parentFlight);
    final routeTitle = [routeFrom, routeTo].where((s) => s != null).join(' → ');
    final airline = pickString(widget.opt, ['airline', 'carrier', 'validating_airline']);
    final title = routeTitle.isNotEmpty ? routeTitle : (airline ?? 'Flight ${widget.optionIndex + 1}');

    final price = isObject(widget.opt['price'])
        ? widget.opt['price'] as Map<String, dynamic>
        : null;
    final priceParts = price != null ? formatAmadeusDualPriceParts(price, tripCurrency) : null;

    final ranking = isObject(widget.opt['_ranking'])
        ? widget.opt['_ranking'] as Map<String, dynamic>
        : null;
    final durationMins = ranking != null ? pickNumber(ranking, ['duration_minutes']) : null;
    final stops = ranking != null ? pickNumber(ranking, ['stops']) : null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isTop ? AppColors.emeraldBorder : AppColors.border.withAlpha(200)),
        borderRadius: BorderRadius.circular(8),
        color: isTop ? AppColors.emeraldBg : AppColors.background.withAlpha(100),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _detailsOpen = !_detailsOpen),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (widget.showChevrons)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(_detailsOpen ? '▼' : '▶',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (priceParts != null)
                              DualPriceDisplay(primary: priceParts.primary, original: priceParts.original),
                            if (durationMins != null)
                              Text(formatDurationMinutesAsHoursMinutes(durationMins),
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            if (stops != null)
                              Text('${stops.toInt()} stops',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_detailsOpen)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: Color(0x19171717),
              ),
              padding: const EdgeInsets.all(10),
              child: _FlightSegmentList(
                source: widget.opt,
                parentFlight: widget.parentFlight,
                maps: maps,
                carriers: carriers,
              ),
            ),
        ],
      ),
    );
  }
}

class _FlightSegmentList extends StatelessWidget {
  final Map<String, dynamic> source;
  final Map<String, dynamic> parentFlight;
  final TripLocationMaps maps;
  final Map<String, String> carriers;

  const _FlightSegmentList({
    required this.source,
    required this.parentFlight,
    required this.maps,
    required this.carriers,
  });

  @override
  Widget build(BuildContext context) {
    final segments = collectSegmentsFromRecord(source);
    if (segments.isEmpty) {
      final fallbackSegments = collectSegmentsFromRecord(parentFlight);
      if (fallbackSegments.isEmpty) {
        return const Text('Per-segment breakdown is not available.',
            style: TextStyle(fontSize: 12, color: AppColors.muted));
      }
      return _buildSegmentCards(fallbackSegments);
    }
    return _buildSegmentCards(segments);
  }

  Widget _buildSegmentCards(List<Map<String, dynamic>> segments) {
    return Column(
      children: segments.asMap().entries.expand((e) {
        final i = e.key;
        final seg = e.value;
        final widgets = <Widget>[_SegmentCard(seg: seg, index: i, total: segments.length, maps: maps, carriers: carriers)];
        if (i < segments.length - 1) {
          final layover = formatConnectionLayover(segments[i], segments[i + 1]);
          if (layover != null) {
            final hub = formatAirportLine(segments[i + 1], 'departure', maps);
            widgets.add(Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border.withAlpha(150), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text.rich(TextSpan(children: [
                const TextSpan(text: 'Connection at ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                TextSpan(text: '$hub · $layover',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.foreground)),
              ])),
            ));
          }
        }
        return widgets;
      }).toList(),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final Map<String, dynamic> seg;
  final int index;
  final int total;
  final TripLocationMaps maps;
  final Map<String, String> carriers;

  const _SegmentCard({
    required this.seg,
    required this.index,
    required this.total,
    required this.maps,
    required this.carriers,
  });

  @override
  Widget build(BuildContext context) {
    final carrier = formatSegmentCarrier(seg, carriers);
    final operatedBy = formatSegmentOperatedBy(seg, carriers);
    final depLoc = formatAirportLine(seg, 'departure', maps);
    final arrLoc = formatAirportLine(seg, 'arrival', maps);
    final dep = formatFlightEndpointFromNested(seg, 'departure');
    final arr = formatFlightEndpointFromNested(seg, 'arrival');
    final duration = formatSegmentDuration(seg);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withAlpha(130)),
        borderRadius: BorderRadius.circular(6),
        color: AppColors.background.withAlpha(80),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Segment ${index + 1}${total > 1 ? ' of $total' : ''}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(carrier, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
          if (operatedBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(operatedBy, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DEPARTURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(depLoc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    Text(dep ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ARRIVAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(arrLoc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    Text(arr ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DURATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(duration ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
