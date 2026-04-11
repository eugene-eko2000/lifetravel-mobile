import 'package:flutter/material.dart';
import '../theme.dart';

class DualPriceDisplay extends StatelessWidget {
  final String primary;
  final String? original;

  const DualPriceDisplay({super.key, required this.primary, this.original});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: primary,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
        ),
        if (original != null)
          TextSpan(
            text: ' ($original)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: AppColors.muted,
            ),
          ),
      ]),
    );
  }
}
