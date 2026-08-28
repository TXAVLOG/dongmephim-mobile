import 'package:flutter/material.dart';
import '../../../services/txa_ad_free_service.dart';

class TxaAdFreeBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const TxaAdFreeBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TxaAdFreeService.instance,
      builder: (context, _) {
        final adFreeService = TxaAdFreeService.instance;
        if (!adFreeService.isAdFreeActive) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  adFreeService.remainingTimeString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
