import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive dialog that allows direct numeric typing of quantity (e.g. 30 units)
Future<int?> showQuantityInputDialog({
  required BuildContext context,
  required int initialQuantity,
  String productName = '',
  int maxQuantity = 99999,
  int minQuantity = 1,
}) async {
  final controller = TextEditingController(
    text: initialQuantity <= 0 ? '1' : '$initialQuantity',
  );
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  return showDialog<int>(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF99F6E4)),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF0F766E),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Enter Quantity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (productName.isNotEmpty) ...[
              Text(
                productName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F766E),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 30',
                labelText: 'Quantity (Units)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                prefixIcon: IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () {
                    final curr = int.tryParse(controller.text) ?? 1;
                    if (curr > minQuantity) {
                      controller.text = '${curr - 1}';
                    }
                  },
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () {
                    final curr = int.tryParse(controller.text) ?? 0;
                    if (curr < maxQuantity) {
                      controller.text = '${curr + 1}';
                    }
                  },
                ),
              ),
              onSubmitted: (val) {
                final parsed = int.tryParse(val.trim());
                if (parsed != null && parsed >= minQuantity) {
                  Navigator.pop(
                    dialogCtx,
                    parsed.clamp(minQuantity, maxQuantity),
                  );
                }
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Quick Select:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [10, 25, 30, 50, 100].map((quickVal) {
                return ActionChip(
                  label: Text(
                    '$quickVal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  onPressed: () {
                    controller.text = '$quickVal';
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= minQuantity) {
                Navigator.pop(
                  dialogCtx,
                  parsed.clamp(minQuantity, maxQuantity),
                );
              } else {
                Navigator.pop(dialogCtx, minQuantity);
              }
            },
            child: const Text('Set Quantity'),
          ),
        ],
      );
    },
  );
}
