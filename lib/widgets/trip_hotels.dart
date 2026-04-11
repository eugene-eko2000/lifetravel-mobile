import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/trip_helpers.dart';
import '../utils/trip_formatting.dart';
import 'dual_price_display.dart';
import 'ranked_trip_card.dart';

class LegHotelsBlock extends StatelessWidget {
  final List<dynamic> hotels;
  final int legIndex;
  final bool showChevrons;
  final void Function(int hotelIndex, List<dynamic> newOptions)? onReorderOptions;

  const LegHotelsBlock({
    super.key,
    required this.hotels,
    required this.legIndex,
    this.showChevrons = false,
    this.onReorderOptions,
  });

  @override
  Widget build(BuildContext context) {
    final list = hotels.whereType<Map<String, dynamic>>().toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hotels',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
        const SizedBox(height: 8),
        ...list.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HotelRow(
                stay: e.value,
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

class _HotelRow extends StatefulWidget {
  final Map<String, dynamic> stay;
  final int labelIndex;
  final int legIndex;
  final bool showChevrons;
  final void Function(List<dynamic> newOptions)? onOptionsReorder;

  const _HotelRow({
    required this.stay,
    required this.labelIndex,
    required this.legIndex,
    this.showChevrons = false,
    this.onOptionsReorder,
  });

  @override
  State<_HotelRow> createState() => _HotelRowState();
}

class _HotelRowState extends State<_HotelRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = TripDataProvider.of(context);
    final maps = provider?.locationMaps ?? const TripLocationMaps();
    final cityCode = pickString(widget.stay, ['city_code', 'city']);
    final options = pickArray(widget.stay, ['options']) ?? [];
    final objectOptions = options.whereType<Map<String, dynamic>>().toList();

    final title = cityCode != null
        ? 'Hotels · ${formatHotelCityLine(cityCode, maps.cityCodeToName)}'
        : 'Hotel ${widget.labelIndex + 1}';

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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                        ),
                        if (objectOptions.length > 1)
                          Text('${objectOptions.length} hotel options',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && objectOptions.isNotEmpty)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: Color(0x19171717),
              ),
              padding: const EdgeInsets.all(10),
              child: _buildOptionsList(objectOptions),
            ),
          if (_expanded && objectOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('No hotel options listed.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
          key: ValueKey('hotel-opt-${widget.legIndex}-${widget.labelIndex}-$i-${objectOptions[i].hashCode}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _HotelOptionBox(
            opt: objectOptions[i],
            optionIndex: i,
            parentStay: widget.stay,
            showChevrons: widget.showChevrons,
          ),
        ),
      );
    }
    return Column(
      children: objectOptions.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HotelOptionBox(
              opt: e.value,
              optionIndex: e.key,
              parentStay: widget.stay,
              showChevrons: widget.showChevrons,
            ),
          )).toList(),
    );
  }
}

class _HotelOptionBox extends StatefulWidget {
  final Map<String, dynamic> opt;
  final int optionIndex;
  final Map<String, dynamic> parentStay;
  final bool showChevrons;

  const _HotelOptionBox({
    required this.opt,
    required this.optionIndex,
    required this.parentStay,
    this.showChevrons = false,
  });

  @override
  State<_HotelOptionBox> createState() => _HotelOptionBoxState();
}

class _HotelOptionBoxState extends State<_HotelOptionBox> {
  bool _detailsOpen = false;

  @override
  Widget build(BuildContext context) {
    final provider = TripDataProvider.of(context);
    final tripCurrency = provider?.tripCurrency;
    final maps = provider?.locationMaps ?? const TripLocationMaps();
    final isTop = widget.optionIndex == 0;

    final h = isObject(widget.opt['hotel'])
        ? widget.opt['hotel'] as Map<String, dynamic>
        : null;
    final name = h != null ? pickString(h, ['name', 'chain', 'brand']) : null;
    final parentCity = pickString(widget.parentStay, ['city_code', 'city']);
    final title = name ?? parentCity ?? 'Hotel ${widget.optionIndex + 1}';

    final priceParts = formatHotelDualPriceParts(widget.opt, tripCurrency, widget.parentStay);

    final cityCode = h != null ? pickString(h, ['city_code', 'cityCode', 'city']) : null;
    final rawCity = cityCode ?? parentCity;
    final cityLine = rawCity != null ? formatHotelCityLine(rawCity, maps.cityCodeToName) : null;

    final cin = asIsoDate(pickString(widget.parentStay, ['check_in', 'checkIn']));
    final cout = asIsoDate(pickString(widget.parentStay, ['check_out', 'checkOut']));
    final dateRight = [cin, cout].where((s) => s != null).join(' → ');

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(title,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                            ),
                            if (dateRight.isNotEmpty)
                              Text(dateRight, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        if (cityLine != null || priceParts != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                if (cityLine != null && cityLine.isNotEmpty)
                                  Text(cityLine, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                if (priceParts != null)
                                  DualPriceDisplay(primary: priceParts.primary, original: priceParts.original),
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
              child: _HotelDetailsPanel(opt: widget.opt),
            ),
        ],
      ),
    );
  }
}

class _HotelDetailsPanel extends StatelessWidget {
  final Map<String, dynamic> opt;
  const _HotelDetailsPanel({required this.opt});

  @override
  Widget build(BuildContext context) {
    final offers = pickArray(opt, ['offers']) ?? [];
    final offer = offers.whereType<Map<String, dynamic>>().firstOrNull;
    if (offer == null) {
      return const Text('No offer details available.',
          style: TextStyle(fontSize: 12, color: AppColors.muted));
    }

    final room = pickRecord(offer, ['room']);
    final typeEst = room != null ? pickRecord(room, ['typeEstimated']) : null;
    final category = typeEst != null ? pickString(typeEst, ['category']) : null;
    final bedType = typeEst != null ? pickString(typeEst, ['bedType']) : null;
    final beds = typeEst?['beds'];
    final policies = pickRecord(offer, ['policies']);
    final paymentType = policies != null ? pickString(policies, ['paymentType']) : null;
    final guests = pickRecord(offer, ['guests']);
    final adults = guests != null ? pickNumber(guests, ['adults']) : null;

    final items = <Widget>[];
    if (category != null) {
      items.add(_DetailRow(label: 'Room type', value: toTitleCaseWords(category)));
    }
    if (bedType != null) {
      final bedsLine = beds is num
          ? '$beds ${toTitleCaseWords(bedType).toLowerCase()} bed${beds == 1 ? '' : 's'}'
          : toTitleCaseWords(bedType);
      items.add(_DetailRow(label: 'Beds', value: bedsLine));
    }
    if (paymentType != null) {
      items.add(_DetailRow(label: 'Payment', value: toTitleCaseWords(paymentType)));
    }
    if (adults != null) {
      items.add(_DetailRow(label: 'Guests', value: '${adults.toInt()} adult${adults == 1 ? '' : 's'}'));
    }

    if (items.isEmpty) {
      return const Text('No room or policy details in this offer.',
          style: TextStyle(fontSize: 12, color: AppColors.muted));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, color: AppColors.foreground)),
        ],
      ),
    );
  }
}
