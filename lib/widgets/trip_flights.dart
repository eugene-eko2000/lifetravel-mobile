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
    final carriers = provider?.carrierMap ?? {};
    final from = pickString(widget.flight, ['from']);
    final to = pickString(widget.flight, ['to']);
    final options = pickArray(widget.flight, ['options']) ?? [];
    final objectOptions = options.whereType<Map<String, dynamic>>().toList();

    final title = [
      resolveFlightHeaderPlaceLabel(from, maps),
      resolveFlightHeaderPlaceLabel(to, maps),
    ].where((s) => s.isNotEmpty).join(' → ');
    final displayTitle = title.isNotEmpty ? title : 'Flight ${widget.labelIndex + 1}';

    final previewSource = objectOptions.isNotEmpty ? objectOptions.first : widget.flight;
    final multiItinLines = getMultiItinerarySummaryLines(previewSource, maps);

    final depSummary = formatFlightEndpointDisplay(widget.flight, 'departure', true);
    final arrSummary = formatFlightEndpointDisplay(widget.flight, 'arrival', true);
    final dateSummary = (depSummary != null && arrSummary != null && depSummary == arrSummary)
        ? depSummary
        : [depSummary, arrSummary].where((s) => s != null).join(' → ');

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
                        if (multiItinLines != null && multiItinLines.length > 1)
                          ...multiItinLines.map((line) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(line,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                              ))
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text.rich(TextSpan(children: [
                                  TextSpan(text: displayTitle,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                                  if (dateSummary.isNotEmpty) ...[
                                    const TextSpan(text: ' · ',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted)),
                                    TextSpan(text: dateSummary,
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ])),
                              ),
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
          if (_expanded && objectOptions.isEmpty)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: Color(0x19171717),
              ),
              padding: const EdgeInsets.all(10),
              child: _FlightSegmentList(
                source: widget.flight,
                parentFlight: widget.flight,
                maps: maps,
                carriers: carriers,
              ),
            ),
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

    final headerRows = getFlightLegHeadersFromOffer(widget.opt, widget.parentFlight, maps);
    final hasHeaderGrid = headerRows.isNotEmpty;

    final routeFrom = pickFlightOptionRouteFrom(widget.opt, widget.parentFlight);
    final routeTo = pickFlightOptionRouteTo(widget.opt, widget.parentFlight);
    final routeTitle = [routeFrom, routeTo].where((s) => s != null).join(' → ');
    final airline = pickString(widget.opt, ['airline', 'carrier', 'validating_airline']);
    final flightNo = pickString(widget.opt, ['flight_number', 'number', 'flight']);
    final carrierLine = formatOptionCarrierAndFlightLine(airline, flightNo, carriers);
    final title = routeTitle.isNotEmpty ? routeTitle : (carrierLine ?? airline ?? 'Flight ${widget.optionIndex + 1}');

    final depart = formatFlightEndpointDisplay(widget.opt, 'departure') ??
        formatFlightEndpointDisplay(widget.parentFlight, 'departure');
    final arrive = formatFlightEndpointDisplay(widget.opt, 'arrival') ??
        formatFlightEndpointDisplay(widget.parentFlight, 'arrival');
    final dateRight = [depart, arrive].where((s) => s != null).join(' → ');

    final price = isObject(widget.opt['price'])
        ? widget.opt['price'] as Map<String, dynamic>
        : null;
    final priceParts = price != null ? formatAmadeusDualPriceParts(price, tripCurrency) : null;

    final ranking = isObject(widget.opt['_ranking'])
        ? widget.opt['_ranking'] as Map<String, dynamic>
        : null;
    final durationMins = !hasHeaderGrid && ranking != null ? pickNumber(ranking, ['duration_minutes']) : null;
    final stops = !hasHeaderGrid && ranking != null ? pickNumber(ranking, ['stops']) : null;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showChevrons)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 2),
                      child: Text(_detailsOpen ? '▼' : '▶',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasHeaderGrid)
                          _FlightLegHeaderGrid(rows: headerRows)
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: Text(title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground))),
                              if (dateRight.isNotEmpty)
                                Text(dateRight, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ],
                        if (priceParts != null || durationMins != null || stops != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (priceParts != null)
                                  DualPriceDisplay(primary: priceParts.primary, original: priceParts.original),
                                if (priceParts != null && (durationMins != null || stops != null))
                                  const Text('·', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                if (durationMins != null)
                                  Text(formatDurationMinutesAsHoursMinutes(durationMins),
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                if (stops != null)
                                  Text('${stops.toInt()} stops',
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
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

class _FlightLegHeaderGrid extends StatelessWidget {
  final List<FlightLegHeaderParts> rows;
  const _FlightLegHeaderGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.map((row) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border.withAlpha(150)),
          color: AppColors.background.withAlpha(80),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.route, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.foreground)),
            const SizedBox(height: 4),
            Text(row.schedule, style: const TextStyle(fontSize: 12, color: AppColors.foreground)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(row.duration, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(width: 16),
                Text(row.stops, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      )).toList(),
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
    final fareSource = source;
    final fareDetailsInOrder = getFirstTravelerFareDetails(fareSource);
    final fareById = buildFareDetailBySegmentId(fareDetailsInOrder);

    final groups = collectSegmentGroups(source);
    final flatCount = groups.fold<int>(0, (n, g) => n + g.length);

    if (flatCount == 0) {
      final fallbackGroups = collectSegmentGroups(parentFlight);
      final fbFlat = fallbackGroups.fold<int>(0, (n, g) => n + g.length);
      if (fbFlat == 0) {
        return const Text('Per-segment breakdown is not available.',
            style: TextStyle(fontSize: 12, color: AppColors.muted));
      }
      return _buildSingleGroup(fallbackGroups.first, 0, fareDetailsInOrder, fareById);
    }

    if (groups.length <= 1) {
      return _buildSingleGroup(groups.first, 0, fareDetailsInOrder, fareById);
    }

    int segStart = 0;
    return Column(
      children: groups.asMap().entries.map((ge) {
        final gi = ge.key;
        final group = ge.value;
        final start = segStart;
        segStart += group.length;
        final label = itineraryGroupLabel(gi, groups.length);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border.withAlpha(180)),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.background.withAlpha(60),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                  color: Color(0x33888888),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppColors.foreground, letterSpacing: 0.5)),
                    if (group.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('${group.length} segments in this direction',
                            style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: _buildGroupCards(group, start, flatCount, fareDetailsInOrder, fareById,
                    segIndexInLeg: true),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleGroup(List<Map<String, dynamic>> segments, int startIdx,
      List<Map<String, dynamic>> fareInOrder, Map<String, Map<String, dynamic>> fareById) {
    return _buildGroupCards(segments, startIdx, segments.length, fareInOrder, fareById);
  }

  Widget _buildGroupCards(List<Map<String, dynamic>> segments, int startIdx, int totalCount,
      List<Map<String, dynamic>> fareInOrder, Map<String, Map<String, dynamic>> fareById,
      {bool segIndexInLeg = false}) {
    return Column(
      children: segments.asMap().entries.expand((e) {
        final si = e.key;
        final seg = e.value;
        final globalIdx = startIdx + si;
        final fareDetail = resolveFareDetail(seg, globalIdx, fareInOrder, fareById);
        final widgets = <Widget>[
          _SegmentCard(
            seg: seg,
            index: segIndexInLeg ? si : globalIdx,
            total: segIndexInLeg ? segments.length : totalCount,
            maps: maps,
            carriers: carriers,
            fareDetail: fareDetail,
          ),
        ];
        if (si < segments.length - 1) {
          final layover = formatConnectionLayover(segments[si], segments[si + 1]);
          if (layover != null) {
            final hub = formatAirportLine(segments[si + 1], 'departure', maps);
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
  final Map<String, dynamic>? fareDetail;

  const _SegmentCard({
    required this.seg,
    required this.index,
    required this.total,
    required this.maps,
    required this.carriers,
    this.fareDetail,
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

    final cabinLabel = fareDetail != null ? formatCabinClassLabel(fareDetail!['cabin']) : null;
    final checkedBags = fareDetail != null ? formatFareBagsLine(pickFareBagsField(fareDetail!, 'checked')) : null;
    final cabinBags = fareDetail != null ? formatFareBagsLine(pickFareBagsField(fareDetail!, 'cabin')) : null;
    final hasFareExtras = cabinLabel != null || checkedBags != null || cabinBags != null;

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
          // Departure / Arrival / Duration table
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border.withAlpha(150))),
            ),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 38,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DEPARTURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(depLoc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                      const SizedBox(height: 2),
                      Text(dep ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 38,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ARRIVAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(arrLoc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                      const SizedBox(height: 2),
                      Text(arr ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DURATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(duration ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasFareExtras) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border.withAlpha(100))),
              ),
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cabinLabel != null)
                    _FareDetailRow(label: 'CABIN CLASS', value: cabinLabel),
                  if (checkedBags != null)
                    _FareDetailRow(label: 'CHECKED BAGS', value: checkedBags),
                  if (cabinBags != null)
                    _FareDetailRow(label: 'CABIN BAGS', value: cabinBags),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FareDetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _FareDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
              color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, color: AppColors.foreground)),
        ],
      ),
    );
  }
}
