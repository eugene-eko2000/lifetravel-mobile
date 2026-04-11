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

    final offer = _getPrimaryHotelOffer(widget.opt);
    final checkInOffer = offer != null ? asIsoDate(pickString(offer, ['checkInDate', 'check_in'])) : null;
    final checkOutOffer = offer != null ? asIsoDate(pickString(offer, ['checkOutDate', 'check_out'])) : null;
    final checkInOpt = h != null ? asIsoDate(pickString(h, ['check_in', 'checkIn'])) : null;
    final checkOutOpt = h != null ? asIsoDate(pickString(h, ['check_out', 'checkOut'])) : null;
    final checkInParent = asIsoDate(widget.parentStay['check_in']);
    final checkOutParent = asIsoDate(widget.parentStay['check_out']);
    final dateRight = [
      checkInOffer ?? checkInOpt ?? checkInParent,
      checkOutOffer ?? checkOutOpt ?? checkOutParent,
    ].where((s) => s != null).join(' → ');

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
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (cityLine != null && cityLine.isNotEmpty)
                                  Text(cityLine, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                if (cityLine != null && cityLine.isNotEmpty && priceParts != null)
                                  const Text('·', style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
          if (_detailsOpen && offer != null)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: Color(0x19171717),
              ),
              padding: const EdgeInsets.all(10),
              child: _HotelStayDetailsPanel(offer: offer),
            ),
          if (_detailsOpen && offer == null)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: Color(0x19171717),
              ),
              padding: const EdgeInsets.all(10),
              child: const Text('No offer details available for this stay.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _getPrimaryHotelOffer(Map<String, dynamic> opt) {
  final offers = pickArray(opt, ['offers']) ?? [];
  final first = offers.whereType<Map<String, dynamic>>().firstOrNull;
  if (first != null) return first;
  if (pickString(opt, ['checkInDate', 'checkOutDate']) != null ||
      pickRecord(opt, ['room']) != null ||
      pickRecord(opt, ['policies']) != null) {
    return opt;
  }
  return null;
}

String? _formatCategoryOrCode(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  return toTitleCaseWords(value.replaceAll('_', ' '));
}

String? _getRoomDescriptionText(Map<String, dynamic>? room, Map<String, dynamic>? roomInfo) {
  final dRoom = room != null ? pickRecord(room, ['description']) : null;
  final tFromRoom = dRoom != null ? pickString(dRoom, ['text']) : null;
  final tFromInfo = roomInfo != null ? pickString(roomInfo, ['description']) : null;
  final a = tFromRoom?.trim() ?? '';
  final b = tFromInfo?.trim() ?? '';
  final best = a.length >= b.length ? a : b;
  return best.isNotEmpty ? best : null;
}

class _HotelStayDetailsPanel extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _HotelStayDetailsPanel({required this.offer});

  @override
  Widget build(BuildContext context) {
    final room = pickRecord(offer, ['room']);
    final roomInfo = pickRecord(offer, ['roomInformation']);
    final typeEst = room != null ? pickRecord(room, ['typeEstimated']) : null;
    final typeEstRi = roomInfo != null ? pickRecord(roomInfo, ['typeEstimated']) : null;
    final category = _formatCategoryOrCode(typeEst?['category'] ?? typeEstRi?['category']);
    final roomTypeCode = pickString(room ?? {}, ['type']) ?? pickString(roomInfo ?? {}, ['type']);
    final bedType = _formatCategoryOrCode(typeEst?['bedType'] ?? typeEstRi?['bedType']);
    final rawBeds = typeEst?['beds'] ?? typeEstRi?['beds'];
    final beds = (rawBeds is num && rawBeds.isFinite) ? rawBeds.toInt() : null;
    final amenities = _getRoomDescriptionText(room, roomInfo);

    final policies = pickRecord(offer, ['policies']);
    final paymentType = policies != null ? pickString(policies, ['paymentType']) : null;
    final refundable = policies != null ? pickRecord(policies, ['refundable']) : null;
    final refundLabel = refundable != null ? pickString(refundable, ['cancellationRefund']) : null;
    final cancellations = policies != null
        ? (pickArray(policies, ['cancellations']) ?? []).whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final prepay = policies != null ? pickRecord(policies, ['prepay']) : null;
    final prepayDeadline = prepay != null ? pickString(prepay, ['deadline']) : null;
    final accepted = prepay != null ? pickRecord(prepay, ['acceptedPayments']) : null;
    final ccList = accepted != null
        ? (pickArray(accepted, ['creditCards']) ?? []).whereType<String>().toList()
        : <String>[];
    final payMethods = accepted != null
        ? (pickArray(accepted, ['methods']) ?? []).whereType<String>().toList()
        : <String>[];

    final rateCode = pickString(offer, ['rateCode']);
    final rateFamily = pickRecord(offer, ['rateFamilyEstimated']);
    final rateFamilyCode = rateFamily != null ? pickString(rateFamily, ['code']) : null;
    final commission = pickRecord(offer, ['commission']);
    final commissionPct = commission != null ? pickScalar(commission, ['percentage']) : null;
    final guests = pickRecord(offer, ['guests']);
    final adults = guests != null ? pickNumber(guests, ['adults']) : null;

    final roomTypeLine = () {
      if (category != null && roomTypeCode != null && roomTypeCode != category) return '$category ($roomTypeCode)';
      if (category != null) return category;
      if (roomTypeCode != null) return roomTypeCode;
      return null;
    }();
    final bedsLine = () {
      if (beds != null && bedType != null) return '$beds ${bedType.toLowerCase()} bed${beds == 1 ? "" : "s"}';
      if (beds != null) return '$beds bed${beds == 1 ? "" : "s"}';
      return bedType;
    }();

    final hasRoomBlock = roomTypeLine != null || bedsLine != null || amenities != null;
    final hasPolicyBlock = paymentType != null || refundLabel != null ||
        cancellations.isNotEmpty || prepayDeadline != null || ccList.isNotEmpty || payMethods.isNotEmpty;
    final hasMetaBlock = rateCode != null || rateFamilyCode != null || commissionPct != null || adults != null;

    if (!hasRoomBlock && !hasPolicyBlock && !hasMetaBlock) {
      return const Text('No room or policy details in this offer.',
          style: TextStyle(fontSize: 12, color: AppColors.muted));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMetaBlock) ...[
          if (rateCode != null)
            _DetailRow(label: 'Rate',
                value: rateFamilyCode != null && rateFamilyCode != rateCode
                    ? '$rateCode · $rateFamilyCode' : rateCode),
          if (commissionPct != null)
            _DetailRow(label: 'Commission', value: '$commissionPct%'),
          if (adults != null)
            _DetailRow(label: 'Guests', value: '${adults.toInt()} adult${adults == 1 ? "" : "s"}'),
        ],
        if (hasRoomBlock) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('ROOM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.muted, letterSpacing: 0.5)),
          ),
          if (roomTypeLine != null) _DetailRow(label: 'Room type', value: roomTypeLine),
          if (bedsLine != null) _DetailRow(label: 'Beds', value: bedsLine),
          if (amenities != null) _DetailRow(label: 'Room amenities', value: amenities),
        ],
        if (hasPolicyBlock) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Text('POLICIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.muted, letterSpacing: 0.5)),
          ),
          if (paymentType != null)
            _DetailRow(label: 'Payment', value: _formatCategoryOrCode(paymentType) ?? paymentType),
          if (refundLabel != null)
            _DetailRow(label: 'Refundability',
                value: _formatCategoryOrCode(refundLabel.replaceAll('_', ' ')) ?? refundLabel),
          ...cancellations.asMap().entries.map((e) {
            final c = e.value;
            final rawDeadline = pickString(c, ['deadline']);
            final deadline = rawDeadline != null ? formatFlightDateTime(rawDeadline) : null;
            final nights = pickNumber(c, ['numberOfNights']);
            final pType = pickString(c, ['policyType']);
            final parts = [
              pType != null ? _formatCategoryOrCode(pType.replaceAll('_', ' ')) : null,
              nights != null ? '${nights.toInt()} night${nights == 1 ? "" : "s"} penalty window' : null,
              deadline != null ? 'by $deadline' : null,
            ].where((s) => s != null).join(' · ');
            return _DetailRow(
                label: cancellations.length > 1 ? 'Cancellation ${e.key + 1}' : 'Cancellation',
                value: parts.isNotEmpty ? parts : '—');
          }),
          if (prepayDeadline != null)
            _DetailRow(label: 'Prepay deadline',
                value: formatFlightDateTime(prepayDeadline) ?? prepayDeadline),
          if (payMethods.isNotEmpty)
            _DetailRow(label: 'Payment methods', value: payMethods.join(', ')),
          if (ccList.isNotEmpty)
            _DetailRow(label: 'Cards accepted', value: ccList.join(', ')),
        ],
      ],
    );
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
