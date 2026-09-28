import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bhandar_api_service.dart';

class OrderCancelDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final VoidCallback onCancelled;

  const OrderCancelDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.onCancelled,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required VoidCallback onCancelled,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => OrderCancelDialog(
        orderId: orderId,
        orderNumber: orderNumber,
        onCancelled: onCancelled,
      ),
    );
  }

  @override
  State<OrderCancelDialog> createState() => _OrderCancelDialogState();
}

class _OrderCancelDialogState extends State<OrderCancelDialog> {
  final List<String> _reasons = [
    "Ordered by mistake",
    "Found cheaper alternative",
    "Delivery time is too long",
    "Want to change delivery address",
    "Other",
  ];
  String _selectedReason = "Ordered by mistake";
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: Color(0xFFE53935), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Cancel Order #${widget.orderNumber}",
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Please select a reason for cancelling this order:",
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            ...List.generate(_reasons.length, (i) {
              final reason = _reasons[i];
              return RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFFE53935),
                title: Text(reason, style: GoogleFonts.inter(fontSize: 13)),
                value: reason,
                groupValue: _selectedReason,
                onChanged: _isSubmitting
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedReason = val);
                      },
              );
            }),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(
            "Back",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  final success = await BhandarApiService.cancelOrder(widget.orderId);
                  if (mounted) {
                    Navigator.pop(context);
                    if (success) {
                      widget.onCancelled();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Order cancelled successfully"),
                          backgroundColor: Color(0xFFE53935),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Could not cancel order. Please try again or contact support."),
                          backgroundColor: Colors.black87,
                        ),
                      );
                    }
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  "Confirm Cancel",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
