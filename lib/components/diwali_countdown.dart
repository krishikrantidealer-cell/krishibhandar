import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class DiwaliSaleController extends ChangeNotifier {
  static final DiwaliSaleController instance = DiwaliSaleController._internal();

  DiwaliSaleController._internal() {
    _initTimer();
  }

  // Exact expiry: 11 November 2026, 11:59:59 PM IST (18:30:00 UTC)
  final DateTime expiryDate = DateTime.utc(2026, 11, 11, 18, 30, 0);

  Duration remainingTime = Duration.zero;
  bool isSaleActive = false;
  Timer? _timer;

  void _initTimer() {
    _updateTime();
    if (isSaleActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTime();
      });
    }
  }

  void _updateTime() {
    final now = DateTime.now().toUtc();
    if (now.isBefore(expiryDate)) {
      remainingTime = expiryDate.difference(now);
      isSaleActive = true;
    } else {
      remainingTime = Duration.zero;
      if (isSaleActive) {
        isSaleActive = false;
        _timer?.cancel();
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class DiwaliPopupManager {
  static bool _hasShownInSession = false;

  static void showPopupIfNeeded(BuildContext context) {
    if (_hasShownInSession) return;
    if (!DiwaliSaleController.instance.isSaleActive) return;

    _hasShownInSession = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Diwali Offer',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _DiwaliLaunchPopup();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        final scale = Tween<double>(begin: 0.7, end: 1.0).animate(curve);
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }
}

class _DiwaliLaunchPopup extends StatefulWidget {
  const _DiwaliLaunchPopup({Key? key}) : super(key: key);

  @override
  State<_DiwaliLaunchPopup> createState() => _DiwaliLaunchPopupState();
}

class _DiwaliLaunchPopupState extends State<_DiwaliLaunchPopup> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  void _onTick() {
    if (!DiwaliSaleController.instance.isSaleActive) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    DiwaliSaleController.instance.addListener(_onTick);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    DiwaliSaleController.instance.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B0B35), // Deep Plum
                Color(0xFF741344), // Wine
                Color(0xFFA51F57), // Magenta
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF5C15D).withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF741344).withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: _FestiveBackgroundPainter(
                      animation: _pulseController,
                      isPopup: true,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF5C15D).withOpacity(_glowAnimation.value),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text('🪔', style: TextStyle(fontSize: 42)),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C15D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF5C15D).withOpacity(0.4)),
                      ),
                      child: const Text(
                        "HAPPY DIWALI",
                        style: TextStyle(
                          color: Color(0xFFF5C15D), // Metallic Gold
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "DIWALI DHAMAKA\nSALE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "The biggest festive savings are here!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AnimatedBuilder(
                      animation: DiwaliSaleController.instance,
                      builder: (context, child) {
                        return _DiwaliTimeRow(time: DiwaliSaleController.instance.remainingTime);
                      },
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF5C15D), // Metallic Gold
                                  Color(0xFFFFD987), // Warm Gold
                                  Color(0xFFF5C15D), // Metallic Gold
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF5C15D).withOpacity(0.35),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "CELEBRATE & SAVE!",
                                  style: TextStyle(
                                    color: Color(0xFF3B0B35), // Deep Plum text for contrast
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Shop your festive favourites today",
                                  style: TextStyle(
                                    color: Color(0xFF741344), // Wine
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return ShaderMask(
                                    blendMode: BlendMode.srcATop,
                                    shaderCallback: (bounds) {
                                      return LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.4),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ).createShader(Rect.fromLTWH(
                                        -bounds.width + (_pulseController.value * bounds.width * 2),
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ));
                                    },
                                    child: Container(color: Colors.transparent),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiwaliCountdownStrip extends StatelessWidget {
  const DiwaliCountdownStrip({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DiwaliSaleController.instance,
      builder: (context, child) {
        if (!DiwaliSaleController.instance.isSaleActive) {
          return const SizedBox.shrink();
        }
        return const _DiwaliCountdownStripContent();
      },
    );
  }
}

class _DiwaliCountdownStripContent extends StatefulWidget {
  const _DiwaliCountdownStripContent({Key? key}) : super(key: key);

  @override
  State<_DiwaliCountdownStripContent> createState() => _DiwaliCountdownStripContentState();
}

class _DiwaliCountdownStripContentState extends State<_DiwaliCountdownStripContent> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B0B35), // Deep Plum
            Color(0xFF741344), // Wine
            Color(0xFFA51F57), // Festive Magenta
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF741344).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF5C15D).withOpacity(0.5), width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FestiveBackgroundPainter(
                animation: _animController,
                isPopup: false,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Text & Icon
              Expanded(
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF5C15D).withOpacity(0.3 + 0.2 * math.sin(_animController.value * math.pi * 2)),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Text('🪔', style: TextStyle(fontSize: 22)),
                        );
                      }
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "DIWALI DHAMAKA SALE",
                              style: TextStyle(
                                color: Color(0xFFF5C15D), // Metallic Gold
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "SALE ENDS IN",
                              style: TextStyle(
                                color: Color(0xFFFFF4DF), // Soft Cream
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Right side: Compact Countdown
              AnimatedBuilder(
                animation: DiwaliSaleController.instance,
                builder: (context, child) {
                  return _DiwaliCompactTimeRow(time: DiwaliSaleController.instance.remainingTime);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiwaliCompactTimeRow extends StatelessWidget {
  final Duration time;
  const _DiwaliCompactTimeRow({Key? key, required this.time}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final days = time.inDays;
    final hours = time.inHours.remainder(24);
    final mins = time.inMinutes.remainder(60);
    final secs = time.inSeconds.remainder(60);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DiwaliCompactTimeBox(label: 'D', value: days),
        const SizedBox(width: 4),
        _DiwaliCompactTimeBox(label: 'H', value: hours),
        const SizedBox(width: 4),
        _DiwaliCompactTimeBox(label: 'M', value: mins),
        const SizedBox(width: 4),
        _DiwaliCompactTimeBox(label: 'S', value: secs),
      ],
    );
  }
}

class _DiwaliCompactTimeBox extends StatelessWidget {
  final String label;
  final int value;
  const _DiwaliCompactTimeBox({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF5C15D).withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              value.toString().padLeft(2, '0'),
              key: ValueKey<int>(value),
              style: const TextStyle(
                color: Color(0xFFFFF4DF), // Soft Cream
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD987), // Warm Gold
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiwaliTimeRow extends StatelessWidget {
  final Duration time;
  const _DiwaliTimeRow({Key? key, required this.time}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final days = time.inDays;
    final hours = time.inHours.remainder(24);
    final mins = time.inMinutes.remainder(60);
    final secs = time.inSeconds.remainder(60);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _DiwaliTimeBox(label: 'DAYS', value: days),
        const SizedBox(width: 12),
        _DiwaliTimeBox(label: 'HOURS', value: hours),
        const SizedBox(width: 12),
        _DiwaliTimeBox(label: 'MINS', value: mins),
        const SizedBox(width: 12),
        _DiwaliTimeBox(label: 'SECS', value: secs),
      ],
    );
  }
}

class _DiwaliTimeBox extends StatelessWidget {
  final String label;
  final int value;
  const _DiwaliTimeBox({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 55,
          height: 55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF5C15D).withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: Text(
              value.toString().padLeft(2, '0'),
              key: ValueKey<int>(value),
              style: const TextStyle(
                color: Color(0xFFFFF4DF), // Soft Cream
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFD987), // Warm Gold
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _FestiveBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isPopup;
  
  _FestiveBackgroundPainter({required this.animation, this.isPopup = false}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Light Sweep
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(
        -size.width + (animation.value * size.width * 2), 
        0, 
        size.width, 
        size.height
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);

    // 2. Golden Particles
    final particlePaint = Paint()..color = const Color(0xFFF5C15D).withOpacity(0.5);
    final int particleCount = isPopup ? 12 : 5;
    for (int i = 0; i < particleCount; i++) {
      double x = (size.width * 0.1 * i + animation.value * 30) % size.width;
      double y = (size.height * 0.2 * i + math.sin(animation.value * math.pi * 2 + i) * 15) % size.height;
      canvas.drawCircle(Offset(x, y), isPopup ? 2.0 : 1.5, particlePaint);
    }

    // 3. Harvest Green accents / Leaves
    final greenPaint = Paint()..color = const Color(0xFF557D37).withOpacity(0.25);
    Path leaf = Path();
    leaf.moveTo(0, 0);
    leaf.quadraticBezierTo(6, -6, 12, 0);
    leaf.quadraticBezierTo(6, 6, 0, 0);
    
    if (isPopup) {
       canvas.save();
       canvas.translate(40, size.height - 50);
       canvas.rotate(-math.pi / 4);
       canvas.drawPath(leaf, greenPaint);
       canvas.restore();
       
       canvas.save();
       canvas.translate(size.width - 40, size.height - 50);
       canvas.rotate(math.pi * 1.2);
       canvas.drawPath(leaf, greenPaint);
       canvas.restore();
    } else {
       canvas.save();
       canvas.translate(size.width * 0.8, size.height * 0.2);
       canvas.rotate(math.pi / 5);
       canvas.drawPath(leaf, greenPaint);
       canvas.restore();
    }

    // 4. Subtle Toran/Fireworks for Popup
    if (isPopup) {
      final fireworkPaint = Paint()
        ..color = const Color(0xFFFFD987).withOpacity(0.4)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
        
      void drawFirework(Offset center, double progress) {
        for (int i = 0; i < 8; i++) {
          double angle = i * math.pi / 4;
          double startRadius = 8 + progress * 5;
          double endRadius = 18 + progress * 15;
          canvas.drawLine(
            Offset(center.dx + math.cos(angle) * startRadius, center.dy + math.sin(angle) * startRadius),
            Offset(center.dx + math.cos(angle) * endRadius, center.dy + math.sin(angle) * endRadius),
            fireworkPaint,
          );
        }
      }
      
      drawFirework(const Offset(40, 50), animation.value);
      drawFirework(Offset(size.width - 40, 70), 1.0 - animation.value);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
