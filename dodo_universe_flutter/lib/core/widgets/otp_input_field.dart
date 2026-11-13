import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Accessible six-digit numeric OTP input widget with rounded boxes and paste support.
class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool enabled;
  final bool hasError;
  final TextEditingController? controller;

  const OtpInputField({
    super.key,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
    this.enabled = true,
    this.hasError = false,
    this.controller,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _internalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _internalController = true;
    }
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    if (_internalController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length) {
      widget.onCompleted?.call(text);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentText = _controller.text;

    return Stack(
      children: [
        // Hidden input handling keyboard, autofill, and paste
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              enableInteractiveSelection: true,
              showCursor: false,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),

        // Visual digit boxes
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (widget.enabled) {
              _focusNode.requestFocus();
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final isFilled = index < currentText.length;
              final digit = isFilled ? currentText[index] : '';
              final isFocused = _focusNode.hasFocus &&
                  (index == currentText.length ||
                      (index == widget.length - 1 &&
                          currentText.length == widget.length));

              Color borderColor = AppTheme.borderSubtle;
              double borderWidth = 1.2;

              if (widget.hasError) {
                borderColor = AppTheme.errorRed;
                borderWidth = 1.5;
              } else if (isFocused) {
                borderColor = AppTheme.borderFocused;
                borderWidth = 2.0;
              } else if (isFilled) {
                borderColor = AppTheme.primaryGreen;
                borderWidth = 1.5;
              }

              return Container(
                width: 48,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryGreenLight
                                .withValues(alpha: 0.8),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  digit,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: widget.hasError
                        ? AppTheme.errorRed
                        : AppTheme.textPrimary,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
