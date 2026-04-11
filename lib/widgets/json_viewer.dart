import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme.dart';

class JsonViewer extends StatefulWidget {
  final dynamic data;
  final bool defaultExpanded;
  const JsonViewer({super.key, required this.data, this.defaultExpanded = false});

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.defaultExpanded) {
      _expandAll(widget.data, '');
    }
  }

  void _expandAll(dynamic data, String path) {
    if (data is Map) {
      _expanded.add(path);
      for (final e in data.entries) {
        _expandAll(e.value, '$path.${e.key}');
      }
    } else if (data is List) {
      _expanded.add(path);
      for (var i = 0; i < data.length; i++) {
        _expandAll(data[i], '$path[$i]');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _buildNode(widget.data, '', 0),
    );
  }

  Widget _buildNode(dynamic data, String path, int depth) {
    if (data is Map) return _buildMap(data, path, depth);
    if (data is List) return _buildList(data, path, depth);
    return _buildPrimitive(data, depth);
  }

  Widget _buildMap(Map data, String path, int depth) {
    final isExpanded = _expanded.contains(path);
    if (data.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: const Text('{}', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            isExpanded ? _expanded.remove(path) : _expanded.add(path);
          }),
          child: Padding(
            padding: EdgeInsets.only(left: depth * 16.0),
            child: Text(
              '${isExpanded ? "▼" : "▶"} {${data.length} keys}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ),
        if (isExpanded)
          ...data.entries.map((e) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: (depth + 1) * 16.0),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '"${e.key}"',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7DD3FC)),
                      ),
                      const TextSpan(
                        text: ': ',
                        style: TextStyle(fontSize: 12, color: AppColors.foreground),
                      ),
                    ]),
                  ),
                ),
                _buildNode(e.value, '$path.${e.key}', depth + 1),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildList(List data, String path, int depth) {
    final isExpanded = _expanded.contains(path);
    if (data.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 16.0),
        child: const Text('[]', style: TextStyle(fontSize: 12, color: AppColors.foreground)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            isExpanded ? _expanded.remove(path) : _expanded.add(path);
          }),
          child: Padding(
            padding: EdgeInsets.only(left: depth * 16.0),
            child: Text(
              '${isExpanded ? "▼" : "▶"} [${data.length} items]',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ),
        if (isExpanded)
          for (var i = 0; i < data.length; i++)
            _buildNode(data[i], '$path[$i]', depth + 1),
      ],
    );
  }

  Widget _buildPrimitive(dynamic data, int depth) {
    Color color;
    String text;
    if (data is String) {
      color = const Color(0xFF4ADE80); // green
      text = '"${data.length > 200 ? '${data.substring(0, 200)}…' : data}"';
    } else if (data is bool) {
      color = const Color(0xFFFB923C); // orange
      text = data.toString();
    } else if (data is num) {
      color = const Color(0xFF60A5FA); // blue
      text = data.toString();
    } else if (data == null) {
      color = AppColors.muted;
      text = 'null';
    } else {
      color = AppColors.foreground;
      text = jsonEncode(data);
    }
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
