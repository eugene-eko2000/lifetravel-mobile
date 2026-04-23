import 'package:flutter/material.dart';

/// Identity wrapper so option maps can be used as [Map] keys (default [Map]
/// equality is deep, not reference).
final class _MapRef {
  const _MapRef(this.map);
  final Map<String, dynamic> map;

  @override
  bool operator ==(Object other) =>
      other is _MapRef && identical(map, other.map);

  @override
  int get hashCode => identityHashCode(map);
}

/// Vertical list of option maps with a FLIP-style translate animation when
/// [onReorder] is used to move an item to the top.
class AnimatedOptionList extends StatefulWidget {
  final List<Map<String, dynamic>> options;
  final void Function(List<dynamic> newOrder)? onReorder;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> opt,
    int index,
    VoidCallback? onSelectToTop,
  ) itemBuilder;

  const AnimatedOptionList({
    super.key,
    required this.options,
    required this.itemBuilder,
    this.onReorder,
  });

  @override
  State<AnimatedOptionList> createState() => _AnimatedOptionListState();
}

class _AnimatedOptionListState extends State<AnimatedOptionList>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  final Map<_MapRef, double> _flipDy = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _offsetFor(Map<String, dynamic> opt) {
    final d = _flipDy[_MapRef(opt)];
    if (d == null) return 0;
    return d * (1 - _curve.value);
  }

  void _selectToTop(List<Map<String, dynamic>> opts, int index) {
    if (index <= 0 || widget.onReorder == null) return;
    if (_controller.isAnimating) return;

    final before = <_MapRef, double>{};
    final oldOrder = List<Map<String, dynamic>>.from(opts);
    for (final o in oldOrder) {
      final box =
          GlobalObjectKey(o).currentContext?.findRenderObject() as RenderBox?;
      before[_MapRef(o)] = box?.localToGlobal(Offset.zero).dy ?? 0.0;
    }

    final next = List<Map<String, dynamic>>.from(opts);
    final moved = next.removeAt(index);
    next.insert(0, moved);
    widget.onReorder!(List<dynamic>.from(next));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = widget.options;
      final after = <_MapRef, double>{};
      for (final o in current) {
        final box =
            GlobalObjectKey(o).currentContext?.findRenderObject() as RenderBox?;
        after[_MapRef(o)] = box?.localToGlobal(Offset.zero).dy ?? 0.0;
      }

      final deltas = <_MapRef, double>{};
      for (final o in current) {
        final k = _MapRef(o);
        final b = before[k];
        final a = after[k];
        if (b != null && a != null && (b - a).abs() > 0.5) {
          deltas[k] = b - a;
        }
      }

      if (deltas.isEmpty) return;

      setState(() {
        _flipDy
          ..clear()
          ..addAll(deltas);
      });
      _controller.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(_flipDy.clear);
        _controller.reset();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSelect = widget.onReorder != null && widget.options.length > 1;
    return Column(
      children: widget.options.asMap().entries.map((e) {
        final i = e.key;
        final opt = e.value;
        return Transform.translate(
          offset: Offset(0, _offsetFor(opt)),
          child: Padding(
            key: GlobalObjectKey(opt),
            padding: const EdgeInsets.only(bottom: 8),
            child: widget.itemBuilder(
              context,
              opt,
              i,
              canSelect && i > 0
                  ? () => _selectToTop(
                        List<Map<String, dynamic>>.from(widget.options),
                        i,
                      )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
