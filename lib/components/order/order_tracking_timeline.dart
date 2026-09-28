import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderTrackingTimeline extends StatelessWidget {
  final String status;
  final bool isCancelled;

  const OrderTrackingTimeline({
    super.key,
    required this.status,
    this.isCancelled = false,
  });

  int get _currentStepIndex {
    if (isCancelled) return -1;
    final s = status.toLowerCase();
    if (s.contains('delivered') || s.contains('completed')) return 3;
    if (s.contains('shipped') || s.contains('transit') || s.contains('delivery')) return 2;
    if (s.contains('processing') || s.contains('packed') || s.contains('confirmed')) return 1;
    return 0; // Placed
  }

  @override
  Widget build(BuildContext context) {
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFC62828), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "This order has been cancelled",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFC62828),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final steps = ["Order Placed", "Confirmed", "Shipped", "Delivered"];
    final current = _currentStepIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final lineStepIndex = index ~/ 2;
            final isLinePassed = lineStepIndex < current;
            return Expanded(
              child: Container(
                height: 3,
                color: isLinePassed ? const Color(0xFF2E7D32) : Colors.grey[300],
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isPassed = stepIndex <= current;
          final isCurrent = stepIndex == current;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPassed ? const Color(0xFF2E7D32) : Colors.white,
                  border: Border.all(
                    color: isPassed ? const Color(0xFF2E7D32) : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isPassed
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: isCurrent ? FontWeight.w700 : (isPassed ? FontWeight.w600 : FontWeight.w400),
                  color: isCurrent ? const Color(0xFF2E7D32) : (isPassed ? Colors.black87 : Colors.grey[500]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
