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
  final effectiveMax = maxQuantity > 0 ? maxQuantity : 1;
  final effectiveInitial = initialQuantity.clamp(minQuantity, effectiveMax);

  final controller = TextEditingController(
    text: '$effectiveInitial',
  );
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  final quickOptions = <int>[10, 25, 30, 50, 100]
      .where((q) => q <= effectiveMax && q >= minQuantity)
      .toList();
  if (quickOptions.isEmpty && effectiveMax > minQuantity) {
    quickOptions.add(effectiveMax);
  }

  return showDialog<int>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final currentVal = int.tryParse(controller.text) ?? minQuantity;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                  const SizedBox(height: 6),
                ],
                if (maxQuantity < 99999) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Available in stock: $effectiveMax units',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
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
                      onPressed: currentVal > minQuantity
                          ? () {
                              final next = (currentVal - 1).clamp(
                                minQuantity,
                                effectiveMax,
                              );
                              controller.text = '$next';
                              setDialogState(() {});
                            }
                          : null,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      onPressed: currentVal < effectiveMax
                          ? () {
                              final next = (currentVal + 1).clamp(
                                minQuantity,
                                effectiveMax,
                              );
                              controller.text = '$next';
                              setDialogState(() {});
                            }
                          : null,
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() {});
                  },
                  onSubmitted: (val) {
                    final parsed = int.tryParse(val.trim());
                    if (parsed != null && parsed >= minQuantity) {
                      Navigator.pop(
                        dialogCtx,
                        parsed.clamp(minQuantity, effectiveMax),
                      );
                    }
                  },
                ),
                if (quickOptions.isNotEmpty) ...[
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
                    children: quickOptions.map((quickVal) {
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
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
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
                      parsed.clamp(minQuantity, effectiveMax),
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
    },
  );
}
