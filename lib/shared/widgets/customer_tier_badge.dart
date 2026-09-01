import 'package:flutter/material.dart';
import 'package:goodwin/models/user_model.dart';

class CustomerTierBadge extends StatelessWidget {
  const CustomerTierBadge({
    super.key,
    required this.tier,
    this.isCompact = true,
  });

  final CustomerTier tier;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    Color bgGradientStart;
    Color bgGradientEnd;
    Color borderColor;
    Color textColor;
    String label;
    String emoji;

    switch (tier) {
      case CustomerTier.diamond:
        bgGradientStart = const Color(0xFF0284C7);
        bgGradientEnd = const Color(0xFF0369A1);
        borderColor = const Color(0xFF38BDF8);
        textColor = Colors.white;
        label = 'Diamond';
        emoji = '💎';
        break;
      case CustomerTier.gold:
        bgGradientStart = const Color(0xFFF59E0B);
        bgGradientEnd = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        textColor = Colors.white;
        label = 'Gold';
        emoji = '🥇';
        break;
      case CustomerTier.silver:
        bgGradientStart = const Color(0xFF64748B);
        bgGradientEnd = const Color(0xFF475569);
        borderColor = const Color(0xFFCBD5E1);
        textColor = Colors.white;
        label = 'Silver';
        emoji = '🥈';
        break;
    }

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: bgGradientEnd.withAlpha(50),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgGradientStart, bgGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            '$label Tier Buyer',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
