import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Authorized Admin Security PINs
const Set<String> _authorizedAdminPins = {'9904', '7860', '1234'};

/// Shows a 4-digit security PIN verification modal for sensitive administrative actions.
Future<bool?> showAdminPinDialog(
  BuildContext context, {
  String actionTitle = 'Authorize Action',
  String reason = 'delete this product listing and move it to the Recycle Bin',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => _AdminPinDialogWidget(
      actionTitle: actionTitle,
      reason: reason,
    ),
  );
}

class _AdminPinDialogWidget extends StatefulWidget {
  final String actionTitle;
  final String reason;

  const _AdminPinDialogWidget({
    required this.actionTitle,
    required this.reason,
  });

  @override
  State<_AdminPinDialogWidget> createState() => _AdminPinDialogWidgetState();
}

class _AdminPinDialogWidgetState extends State<_AdminPinDialogWidget> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyPin(String enteredPin) {
    final pin = enteredPin.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Please enter all 4 digits');
      return;
    }

    if (_authorizedAdminPins.contains(pin)) {
      Navigator.pop(context, true);
    } else {
      _isResetting = true;
      _pinController.clear();
      _isResetting = false;
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  widget.actionTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your 4-digit security PIN to ${widget.reason}:',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Visual 4-Digit Box Display
            AnimatedBuilder(
              animation: _pinController,
              builder: (context, _) {
                final currentText = _pinController.text;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final hasDigit = index < currentText.length;
                    return Container(
                      width: 50,
                      height: 54,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: hasDigit
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _errorMessage != null
                              ? const Color(0xFFDC2626)
                              : hasDigit
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFCBD5E1),
                          width: hasDigit ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hasDigit ? '●' : '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            // Invisible TextField to capture numeric keyboard input
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 1,
                child: TextField(
                  controller: _pinController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onChanged: (val) {
                    if (_isResetting) return;
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                    if (val.length == 4) {
                      _verifyPin(val);
                    }
                  },
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Default PIN: 9904 (or 7860)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _verifyPin(_pinController.text),
          child: const Text('Confirm PIN'),
        ),
      ],
    );
  }
}
