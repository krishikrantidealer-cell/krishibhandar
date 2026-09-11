import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'otp_view.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../controller/constants.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final _globalFormKey = GlobalKey<FormState>();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();

    _phoneFocusNode.addListener(() {
      setState(() {
        _isFocused = _phoneFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _sendOtp() {
    if (!_globalFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    context.read<AuthBloc>().add(SendOtpEvent(phone: phone));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is OtpSentState) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpView(
                phone: state.phone,
                verificationId: '',
                otpCode: state.otpCode,
              ),
            ),
          );
        } else if (state is AuthErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.message,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoadingState;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FBFA),
          body: Stack(
            children: [
              // Top ambient background glow
              Positioned(
                top: -80,
                left: -60,
                right: -60,
                height: 280,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.9,
                      colors: [
                        Constants.baseColor.withValues(alpha: 0.14),
                        Constants.baseColor.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Form(
                          key: _globalFormKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 10),

                              // Brand Logo with glowing container
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Constants.baseColor.withValues(alpha: 0.12),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Constants.baseColor.withValues(alpha: 0.15),
                                    width: 1.5,
                                  ),
                                ),
                                child: Hero(
                                  tag: 'app_logo',
                                  child: Image.asset(
                                    'assets/logo-removebg-preview.png',
                                    height: 64,
                                    width: 64,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // App Tagline / Title
                              Text(
                                l10n.welcomeTo,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.loginPrompt,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Card Container for Input
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.phone_android_rounded, size: 16, color: Constants.baseColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.mobileNumber,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Phone Input Field
                                    TextFormField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocusNode,
                                      keyboardType: TextInputType.phone,
                                      autofillHints: const [AutofillHints.telephoneNumber],
                                      maxLength: 10,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (_) => setState(() {}),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        isDense: true,
                                        prefixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 14),
                                            Text(
                                              '+91',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              height: 20,
                                              width: 1.2,
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                        ),
                                        suffixIcon: _phoneController.text.trim().length == 10
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.green.shade600,
                                                size: 20,
                                              )
                                            : (_phoneController.text.isNotEmpty
                                                ? IconButton(
                                                    splashRadius: 16,
                                                    icon: Icon(
                                                      Icons.cancel_rounded,
                                                      color: Colors.grey.shade400,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      _phoneController.clear();
                                                      setState(() {});
                                                    },
                                                  )
                                                : null),
                                        hintText: l10n.enterMobile,
                                        hintStyle: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0,
                                        ),
                                        filled: true,
                                        fillColor: _isFocused
                                            ? Colors.white
                                            : const Color(0xFFF8FAFC),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Constants.baseColor, width: 1.8),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.red.shade300),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return l10n.enterMobileValid;
                                        }
                                        if (value.trim().length != 10) {
                                          return l10n.enterMobile10;
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),

                                     // Send OTP Animated Button
                                     AnimatedScale(
                                       scale: _isPressed ? 0.97 : 1.0,
                                       duration: const Duration(milliseconds: 100),
                                       child: AnimatedContainer(
                                         duration: const Duration(milliseconds: 250),
                                         curve: Curves.easeOutCubic,
                                         width: double.infinity,
                                         height: 50,
                                         decoration: BoxDecoration(
                                           color: _phoneController.text.trim().length == 10
                                               ? Constants.baseColor
                                               : Constants.baseColor.withValues(alpha: 0.7),
                                           borderRadius: BorderRadius.circular(12),
                                           boxShadow: _phoneController.text.trim().length == 10 && !isLoading
                                               ? [
                                                   BoxShadow(
                                                     color: Constants.baseColor.withValues(alpha: 0.32),
                                                     blurRadius: 14,
                                                     offset: const Offset(0, 5),
                                                   ),
                                                 ]
                                               : [],
                                         ),
                                         child: Material(
                                           color: Colors.transparent,
                                           child: InkWell(
                                             borderRadius: BorderRadius.circular(12),
                                             onTapDown: (_) => setState(() => _isPressed = true),
                                             onTapUp: (_) => setState(() => _isPressed = false),
                                             onTapCancel: () => setState(() => _isPressed = false),
                                             onTap: isLoading ? null : _sendOtp,
                                             child: Center(
                                               child: AnimatedSwitcher(
                                                 duration: const Duration(milliseconds: 200),
                                                 child: isLoading
                                                     ? const SizedBox(
                                                         key: ValueKey('loading'),
                                                         width: 22,
                                                         height: 22,
                                                         child: CircularProgressIndicator(
                                                           color: Colors.white,
                                                           strokeWidth: 2.5,
                                                         ),
                                                       )
                                                     : Row(
                                                         key: const ValueKey('content'),
                                                         mainAxisAlignment: MainAxisAlignment.center,
                                                         children: [
                                                           Text(
                                                             l10n.sendOtp,
                                                             style: GoogleFonts.plusJakartaSans(
                                                               fontSize: 15,
                                                               fontWeight: FontWeight.w700,
                                                               letterSpacing: 0.3,
                                                               color: Colors.white,
                                                             ),
                                                           ),
                                                           const SizedBox(width: 8),
                                                           AnimatedSlide(
                                                             duration: const Duration(milliseconds: 250),
                                                             curve: Curves.easeOutCubic,
                                                             offset: _phoneController.text.trim().length == 10
                                                                 ? const Offset(0.2, 0)
                                                                 : Offset.zero,
                                                             child: const Icon(
                                                               Icons.arrow_forward_rounded,
                                                               size: 18,
                                                               color: Colors.white,
                                                             ),
                                                           ),
                                                         ],
                                                       ),
                                               ),
                                             ),
                                           ),
                                         ),
                                       ),
                                     ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              // Security Guarantee Note
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    "We'll send a 6-digit OTP for instant login",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Terms and Policy Footer
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    l10n.agreeTermsMsg,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final uri = Uri.parse(
                                          'https://krishibhandar.com/pages/terms-condition?_pos=1&_psq=terms&_ss=e&_v=1.0');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Text(
                                      l10n.termsConditions,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: Constants.baseColor,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l10n.and,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final uri = Uri.parse(
                                          'https://krishibhandar.com/pages/privacy-policy?_pos=1&_sid=640bbf90d&_ss=r');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Text(
                                      l10n.privacyPolicy,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: Constants.baseColor,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
