import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Cooldown timer widget for OTP resend actions with automatic lifecycle cleanup.
class CooldownTimer extends StatefulWidget {
  final int cooldownSeconds;
  final FutureOr<void> Function() onResend;
  final String prefixText;
  final String resendLabel;
  final bool autoStart;

  const CooldownTimer({
    super.key,
    this.cooldownSeconds = 60,
    required this.onResend,
    this.prefixText = "Didn't receive the code?",
    this.resendLabel = 'Resend OTP',
    this.autoStart = true,
  });

  @override
  State<CooldownTimer> createState() => _CooldownTimerState();
}

class _CooldownTimerState extends State<CooldownTimer> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.autoStart ? widget.cooldownSeconds : 0;
    if (widget.autoStart) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.cooldownSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _handleResend() async {
    if (_remainingSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await widget.onResend();
      if (mounted) {
        _startTimer();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  String _formattedTime() {
    final minutes = (_remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = _remainingSeconds == 0 && !_isResending;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          '${widget.prefixText} ',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        if (_isResending)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          )
        else if (canResend)
          TextButton(
            onPressed: _handleResend,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.resendLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            '${widget.resendLabel} in ${_formattedTime()}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
