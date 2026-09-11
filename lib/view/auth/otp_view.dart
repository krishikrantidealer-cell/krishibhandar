import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';
import 'complete_profile_view.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';

class OtpView extends StatefulWidget {
  final String phone;
  final String verificationId;
  final String? otpCode;

  const OtpView({
    super.key,
    required this.phone,
    required this.verificationId,
    this.otpCode,
  });

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _resendCountdown = 30;
  Timer? _timer;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (widget.otpCode != null && widget.otpCode!.isNotEmpty) {
      _otpController.text = widget.otpCode!;
    }
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _resendCountdown--);
      }
    });
  }

  void _verifyOtp(String pin) {
    if (pin.length < 6) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(VerifyOtpEvent(phone: widget.phone, otp: pin));
  }

  void _resendOtp() {
    if (_resendCountdown > 0) return;
    context.read<AuthBloc>().add(SendOtpEvent(phone: widget.phone));
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Constants.baseColor, width: 2),
      color: Colors.white,
    );

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          if (state.isProfileCompleted) {
            Routers.goToHome(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CompleteProfileView(
                  phone: state.phone,
                  customerId: state.customerId,
                  name: state.name,
                ),
              ),
            );
          }
        } else if (state is AuthErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _otpController.clear();
          _focusNode.requestFocus();
        } else if (state is OtpSentState) {
          _startResendTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.otpSentAgain),
              backgroundColor: Constants.baseColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoadingState;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.grey.shade700, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Constants.baseColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.sms_rounded,
                            color: Constants.baseColor, size: 32),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        AppLocalizations.of(context)!.verifyPhone,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.3),
                      ),
                      const SizedBox(height: 8),

                      // Phone number display
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.enterOtpPrompt,
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+91 ${widget.phone}',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Pinput Widget
                      Center(
                        child: Pinput(
                          length: 6,
                          controller: _otpController,
                          focusNode: _focusNode,
                          autofocus: true,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          hapticFeedbackType: HapticFeedbackType.lightImpact,
                          onCompleted: _verifyOtp,
                          cursor: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 9),
                                width: 22,
                                height: 1,
                                color: Constants.baseColor,
                              ),
                            ],
                          ),
                          autofillHints: const [AutofillHints.oneTimeCode],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () => _verifyOtp(_otpController.text),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.baseColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Text(AppLocalizations.of(context)!.verifyOtp,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Resend
                      Center(
                        child: _resendCountdown > 0
                            ? Text.rich(
                                TextSpan(
                                  text:
                                      AppLocalizations.of(context)!.resendOtpIn,
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14),
                                  children: [
                                    TextSpan(
                                      text:
                                          '0:${_resendCountdown.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          color: Constants.baseColor,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              )
                            : GestureDetector(
                                onTap: _resendOtp,
                                child: Text(
                                  AppLocalizations.of(context)!.resendOtp,
                                  style: TextStyle(
                                      color: Constants.baseColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
