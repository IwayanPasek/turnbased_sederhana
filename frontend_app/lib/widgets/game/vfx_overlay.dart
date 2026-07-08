// lib/widgets/game/vfx_overlay.dart
import 'dart:math';
import 'package:flutter/material.dart';

class VFXEffect {
  final String id;
  final String text;
  final Color color;
  final bool isIcon;

  VFXEffect({
    required this.id,
    required this.text,
    required this.color,
    this.isIcon = false,
  });
}

class VFXOverlay extends StatefulWidget {
  final Widget child;
  final List<VFXEffect> effects;

  const VFXOverlay({
    super.key,
    required this.child,
    required this.effects,
  });

  @override
  State<VFXOverlay> createState() => _VFXOverlayState();
}

class _VFXOverlayState extends State<VFXOverlay> {
  final Map<String, Widget> _activeWidgets = {};

  @override
  void didUpdateWidget(VFXOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Find new effects
    final newEffects = widget.effects.where((e) => 
        !oldWidget.effects.any((old) => old.id == e.id)).toList();
        
    for (var effect in newEffects) {
      _triggerEffect(effect);
    }
  }

  void _triggerEffect(VFXEffect effect) {
    setState(() {
      _activeWidgets[effect.id] = _buildAnimatedEffect(effect);
    });

    // Remove after animation finishes (1.2 second)
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _activeWidgets.remove(effect.id);
        });
      }
    });
  }

  Widget _buildAnimatedEffect(VFXEffect effect) {
    return _AnimatedVFX(
      key: ValueKey(effect.id),
      effect: effect,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        ..._activeWidgets.values,
      ],
    );
  }
}

class _AnimatedVFX extends StatefulWidget {
  final VFXEffect effect;

  const _AnimatedVFX({super.key, required this.effect});

  @override
  State<_AnimatedVFX> createState() => _AnimatedVFXState();
}

class _AnimatedVFXState extends State<_AnimatedVFX>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yOffset;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  final double _randomX = (Random().nextDouble() - 0.5) * 60.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _yOffset = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 20, end: -40).chain(CurveTween(curve: Curves.easeOutCirc)), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: -40, end: -20).chain(CurveTween(curve: Curves.easeInQuad)), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: -20, end: -70).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 65),
    ]).animate(_controller);

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.6), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.6, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.4), weight: 20),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_randomX, _yOffset.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            ),
          );
        },
        child: Center(
          child: widget.effect.isIcon
              ? Text(
                  widget.effect.text,
                  style: const TextStyle(fontSize: 48),
                )
              : Text(
                  widget.effect.text,
                  style: TextStyle(
                    color: widget.effect.color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
