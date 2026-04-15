import 'package:flutter/material.dart';
import '../utils/trip_helpers.dart';
import '../theme.dart';
import 'ranked_trip_card.dart';

bool looksLikeTrip(dynamic data) {
  if (!isObject(data)) return false;
  final d = data as Map<String, dynamic>;
  if (d.containsKey('trip') && isObject(d['trip'])) return true;
  if (d.containsKey('ranked_trip') && isObject(d['ranked_trip'])) return true;
  if (d.containsKey('itinerary') && isObject(d['itinerary'])) return true;
  if (d.containsKey('ranked_itinerary') && isObject(d['ranked_itinerary'])) return true;
  if (d.containsKey('ranked') && isObject(d['ranked'])) return true;
  if (d['days'] is List) return true;
  if (d['day_plans'] is List) return true;
  if (d['dayPlans'] is List) return true;
  if (d.containsKey('data') && isObject(d['data'])) {
    final inner = d['data'] as Map<String, dynamic>;
    if (inner.containsKey('trip') && isObject(inner['trip'])) return true;
    if (inner.containsKey('ranked_trip') && isObject(inner['ranked_trip'])) return true;
    if (inner.containsKey('itinerary') && isObject(inner['itinerary'])) return true;
    if (inner.containsKey('ranked_itinerary') && isObject(inner['ranked_itinerary'])) return true;
    if (inner.containsKey('ranked') && isObject(inner['ranked'])) return true;
    if (inner['days'] is List) return true;
    if (inner['day_plans'] is List) return true;
    if (inner['dayPlans'] is List) return true;
  }
  return false;
}

Map<String, dynamic>? _normalizeTripRoot(dynamic data) {
  if (!isObject(data)) return null;
  final d = data as Map<String, dynamic>;
  for (final k in ['trip', 'ranked_trip', 'itinerary', 'ranked_itinerary', 'ranked']) {
    if (d.containsKey(k) && isObject(d[k])) return d[k] as Map<String, dynamic>;
  }
  if (d.containsKey('data') && isObject(d['data'])) {
    final inner = d['data'] as Map<String, dynamic>;
    for (final k in ['trip', 'ranked_trip', 'itinerary', 'ranked_itinerary', 'ranked']) {
      if (inner.containsKey(k) && isObject(inner[k])) return inner[k] as Map<String, dynamic>;
    }
    return inner;
  }
  return d;
}

class TripCard extends StatelessWidget {
  final dynamic data;
  final bool detailed;
  /// When true (e.g. full-screen modal), surfaces use solid theme colors instead of chat translucency.
  final bool opaqueLayers;
  const TripCard({super.key, required this.data, this.detailed = false, this.opaqueLayers = false});

  @override
  Widget build(BuildContext context) {
    if (isObject(data)) {
      final d = data as Map<String, dynamic>;
      if (d.containsKey('ranked_trip') && isObject(d['ranked_trip'])) {
        return RankedTripCard(
          envelope: d,
          ranked: d['ranked_trip'] as Map<String, dynamic>,
          detailed: detailed,
          opaqueLayers: opaqueLayers,
        );
      }
      if (d.containsKey('ranked_itinerary') && isObject(d['ranked_itinerary'])) {
        return RankedTripCard(
          envelope: d,
          ranked: d['ranked_itinerary'] as Map<String, dynamic>,
          detailed: detailed,
          opaqueLayers: opaqueLayers,
        );
      }
    }

    final root = _normalizeTripRoot(data);
    if (root == null) return const SizedBox.shrink();

    final title = pickString(root, ['title', 'name']) ??
        pickString(root, ['destination', 'location', 'city', 'country']) ??
        'Trip';
    final subtitleParts = <String>[];
    final dest = pickString(root, ['destination', 'location']);
    final start = pickString(root, ['start_date', 'startDate', 'from', 'start']);
    final end = pickString(root, ['end_date', 'endDate', 'to', 'end']);
    final dur = pickString(root, ['duration', 'duration_days', 'durationDays']);
    if (dest != null && dest != title) subtitleParts.add(dest);
    if (start != null || end != null) {
      subtitleParts.add([start, end].where((s) => s != null).join(' → '));
    }
    if (dur != null) subtitleParts.add(dur);

    final summary = pickString(root, ['summary', 'overview', 'description']) ??
        pickString(root, ['notes']);
    final days = pickArray(root, ['days', 'day_plans', 'dayPlans']) ?? [];
    final layers = TripLayers.of(opaqueLayers);

    return Container(
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
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (subtitleParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitleParts.join(' • '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(summary, style: const TextStyle(fontSize: 14, color: AppColors.foreground)),
            ),
          if (days.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Days',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
            ),
            const SizedBox(height: 8),
            ...days.take(7).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final d = entry.value;
              final dayObj = isObject(d) ? d as Map<String, dynamic> : null;
              final dayTitle =
                  (dayObj != null ? pickString(dayObj, ['title', 'name']) : null) ?? 'Day ${idx + 1}';
              final dayDate = dayObj != null ? pickString(dayObj, ['date', 'day', 'start_date']) : null;
              final activities =
                  dayObj != null ? (pickArray(dayObj, ['activities', 'items', 'plan']) ?? []) : [];
              return _DayTile(layers: layers, title: dayTitle, date: dayDate, activities: activities);
            }),
            if (days.length > 7)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Showing first 7 days…',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
          ],
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final TripLayers layers;
  final String title;
  final String? date;
  final List<dynamic> activities;
  const _DayTile({required this.layers, required this.title, this.date, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: layers.background,
        border: Border.all(color: layers.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.foreground)),
              ),
              if (date != null) Text(date!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          if (activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: activities.take(4).map((a) {
                  final text = a is String
                      ? a
                      : isObject(a)
                          ? (pickString(a as Map<String, dynamic>, ['title', 'name', 'description']) ??
                              a.toString())
                          : a.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 14, color: AppColors.foreground)),
                        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.foreground))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
