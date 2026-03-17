import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/push_token_sync_service.dart';
import '../theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.mobileNo,
    required this.sessionId,
  });

  final String mobileNo;
  final String sessionId;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  late String _sessionId;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startResendTimer();
    });
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 59);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyOtp() async {
    final String otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showSnack('Please enter a valid 6-digit OTP');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showSnack('OTP must contain only numbers');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = await _authService.verifyMobileOtp(
        mobileNo: widget.mobileNo,
        otp: otp,
        sessionId: _sessionId,
      );

      if (session.success) {
        if (!_authService.hasAdminAccess(session)) {
          await _authService.clearSession();
          if (!mounted) {
            return;
          }
          _showSnack('This mobile number is not allowed in AstroAdmin.');
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (!mounted) {
            return;
          }
          Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);
          return;
        }

        await _authService.saveSession(session);
        await PushTokenSyncService.syncNow();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              session.message.isEmpty ? 'Login successful' : session.message,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (Route<dynamic> route) => false,
        );
      } else {
        _showSnack(
          session.message.trim().isEmpty
              ? 'Invalid OTP. Please try again.'
              : session.message,
        );
        _otpController.clear();
      }
    } catch (error) {
      final String message = error.toString();
      String errorMessage = 'Invalid OTP. Please try again';

      if (message.contains('401')) {
        errorMessage = 'Invalid OTP. Please enter the correct OTP';
      } else if (message.contains('Connection refused') ||
          message.contains('SocketException') ||
          message.contains('connection error')) {
        errorMessage =
            'Unable to connect to server. Please check your internet connection and try again';
      } else if (message.contains('500')) {
        errorMessage = 'Server error. Please try again later';
      } else if (message.contains('timeout')) {
        errorMessage =
            'Request timeout. Please check your connection and try again';
      }

      _showSnack(errorMessage);
      _otpController.clear();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await _authService.sendMobileOtp(widget.mobileNo);
      if (!response.success || response.sessionId.trim().isEmpty) {
        _showSnack(
          response.message.trim().isEmpty
              ? 'Unable to resend OTP'
              : response.message,
        );
        return;
      }
      _sessionId = response.sessionId;
      _otpController.clear();
      _resendTimer?.cancel();
      _startResendTimer();
      _showSnack('OTP resent successfully');
    } catch (error) {
      _showSnack('Unable to resend OTP');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Widget _buildTimerRing() {
    final int minutes = _resendCountdown ~/ 60;
    final int seconds = _resendCountdown % 60;
    final double timerPercentage = _resendCountdown / 60;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: 176,
          height: 176,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          height: 160,
          child: CircularProgressIndicator(
            value: timerPercentage,
            strokeWidth: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              _resendCountdown <= 15 ? Colors.redAccent : Colors.white,
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _resendCountdown <= 15 ? 'Hurry up!' : 'Time left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(7.5),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AdminAppTheme.midnight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.phone_android_rounded,
                    color: AdminAppTheme.midnight,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Your Number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+91 ${widget.mobileNo}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AdminAppTheme.midnight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AdminAppTheme.midnight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    final bool isOtpComplete = _otpController.text.length == 6;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(7.5),
        border: Border.all(
          color:
              isOtpComplete ? AdminAppTheme.midnight : const Color(0xFFE0E0E0),
          width: isOtpComplete ? 2.5 : 1.5,
        ),
      ),
      child: TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        enabled: !_isLoading,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (String value) {
          setState(() {});
          if (value.length == 6) {
            _verifyOtp();
          }
        },
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 16,
          color: AdminAppTheme.midnight,
        ),
        decoration: InputDecoration(
          hintText: '000000',
          hintStyle: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 16,
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.5),
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AdminAppTheme.midnight, AdminAppTheme.gold],
        ),
        borderRadius: BorderRadius.circular(7.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AdminAppTheme.gold.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _verifyOtp,
          borderRadius: BorderRadius.circular(7.5),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'VERIFY & LOGIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendButton() {
    final bool isEnabled = _resendCountdown <= 0 && !_isLoading;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? _resendOtp : null,
          borderRadius: BorderRadius.circular(7.5),
          child: Container(
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(7.5),
              border: Border.all(
                color: isEnabled
                    ? AdminAppTheme.midnight
                    : const Color(0xFFE0E0E0),
                width: 2,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'RESEND OTP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isEnabled
                          ? AdminAppTheme.midnight
                          : const Color(0xFF666666),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_resendCountdown > 0) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      '(${_resendCountdown}s)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: <Widget>[
            const Text(
              'Verify Your Phone',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We sent a 6-digit OTP to your number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 28),
            _buildPhoneInfoCard(),
            const SizedBox(height: 28),
            _buildOtpInput(),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AdminAppTheme.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AdminAppTheme.gold.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'Admin access is verified after OTP confirmation.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminAppTheme.gold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            _buildVerifyButton(),
            const SizedBox(height: 26),
            _buildResendButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AdminAppTheme.midnight.withValues(alpha: 0.9),
                  AdminAppTheme.gold.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          Positioned(
            top: -30,
            left: -10,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: screenHeight * 0.55,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 24,
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTimerRing(),
                  const SizedBox(height: 24),
                  _buildOtpCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
