import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable labelled numeric input field for the MFR Virtual Lab.
///
/// Shows [label] as the floating label, [unit] as an inline suffix,
/// a red border + error message when [errorText] is non-null, and
/// a grey non-interactive state when [enabled] is false.
class MFRInputField extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  const MFRInputField({
    super.key,
    required this.label,
    required this.unit,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Only allow digits, dots, and a leading minus sign
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: enabled ? const Color(0xFF212121) : const Color(0xFF9E9E9E),
      ),
      decoration: InputDecoration(
        // ── Labels ────────────────────────────────────────────────────
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13,
          color: hasError
              ? const Color(0xFFD32F2F)
              : enabled
                  ? const Color(0xFF757575)
                  : const Color(0xFFBDBDBD),
        ),

        // ── Unit suffix ───────────────────────────────────────────────
        suffix: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFFE8EAF6) // light indigo tint
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF1A237E)
                  : const Color(0xFFBDBDBD),
              letterSpacing: 0.3,
            ),
          ),
        ),

        // ── Error text ────────────────────────────────────────────────
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(
          color: Color(0xFFD32F2F),
          fontSize: 11.5,
          height: 1.3,
        ),

        // ── Fill ──────────────────────────────────────────────────────
        filled: true,
        fillColor: enabled
            ? Colors.white
            : const Color(0xFFF5F5F5), // grey when disabled

        // ── Borders ───────────────────────────────────────────────────
        border: _border(const Color(0xFFBDBDBD)),

        enabledBorder: _border(
          hasError ? const Color(0xFFD32F2F) : const Color(0xFFBDBDBD),
        ),

        focusedBorder: _thickBorder(
          hasError ? const Color(0xFFD32F2F) : const Color(0xFF1A237E),
        ),

        disabledBorder: _border(const Color(0xFFE0E0E0)),

        errorBorder: _border(const Color(0xFFD32F2F)),

        focusedErrorBorder: _thickBorder(const Color(0xFFD32F2F)),

        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color),
      );

  static OutlineInputBorder _thickBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: 2),
      );
}
