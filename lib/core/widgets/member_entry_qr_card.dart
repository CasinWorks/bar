import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_colors.dart';

/// Large scannable entry QR used at the door and on event guest passes.
class MemberEntryQrCard extends StatelessWidget {
  const MemberEntryQrCard({
    super.key,
    required this.data,
    this.headline = 'DOOR CHECK-IN',
    this.size = 240,
  });

  final String data;
  final String headline;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successGreen, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.successGreen.withValues(alpha: 0.28),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            headline,
            style: const TextStyle(
              color: AppColors.successGreen,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          QrImageView(data: data, version: QrVersions.auto, size: size),
        ],
      ),
    );
  }
}
