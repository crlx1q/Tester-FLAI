import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedFire extends StatefulWidget {
  final double size;
  final bool isActive;
  final Color? inactiveColor;

  const AnimatedFire({
    super.key,
    this.size = 18,
    this.isActive = true,
    this.inactiveColor,
  });

  @override
  State<AnimatedFire> createState() => _AnimatedFireState();
}

class _AnimatedFireState extends State<AnimatedFire>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedFire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _glowController.stop();
      _pulseController.reset();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Icon(
        Icons.local_fire_department,
        size: widget.size,
        color: widget.inactiveColor ?? const Color(0xFF94A3B8),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Glow effect
              Container(
                width: widget.size * 1.6,
                height: widget.size * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35)
                          .withOpacity(_glowAnimation.value * 0.5),
                      blurRadius: widget.size * 0.8,
                      spreadRadius: widget.size * 0.1,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD700)
                          .withOpacity(_glowAnimation.value * 0.3),
                      blurRadius: widget.size * 0.4,
                      spreadRadius: widget.size * 0.05,
                    ),
                  ],
                ),
              ),
              // Fire icon with gradient
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFF6B35),
                    Color(0xFFFF4500),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Icon(
                  Icons.local_fire_department,
                  size: widget.size,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
