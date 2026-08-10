import 'package:flutter/material.dart';

import 'app_theme.dart';

/// РђРЅРёРјРёСЂРѕРІР°РЅРЅС‹Р№ РїРµСЂРµС…РѕРґ РјРµР¶РґСѓ СЌРєСЂР°РЅР°РјРё.
class FadeScaleTransition extends PageRouteBuilder {
  final Widget child;
  FadeScaleTransition({required this.child})
    : super(
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (_, a, _, child) {
          final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.95, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      );
}

/// РђРЅРёРјР°С†РёСЏ РїРѕСЏРІР»РµРЅРёСЏ СЃРѕРѕР±С‰РµРЅРёСЏ.
class MessageSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const MessageSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<MessageSlideIn> createState() => _MessageSlideInState();
}

class _MessageSlideInState extends State<MessageSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// РџСѓР»СЊСЃРёСЂСѓСЋС‰Р°СЏ Р°РЅРёРјР°С†РёСЏ РґР»СЏ РёРЅРґРёРєР°С‚РѕСЂРѕРІ.
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _animation = Tween(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

/// РђРЅРёРјР°С†РёСЏ РЅР°Р±РѕСЂР° С‚РµРєСЃС‚Р° (С‚СЂРё С‚РѕС‡РєРё).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
        lowerBound: 0.0,
        upperBound: 1.0,
      ),
    );
    _animations = _controllers
        .map((c) => Tween(begin: 0.0, end: 1.0).animate(c))
        .toList();
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _animations[i],
          builder: (_, _) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: GBTheme.textSecondary.withValues(
                alpha: 0.4 + 0.6 * _animations[i].value,
              ),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
