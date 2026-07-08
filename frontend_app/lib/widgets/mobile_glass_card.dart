import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glass‑morphism card designed for mobile layouts.
///
/// The widget creates a translucent background with a blur effect
/// (commonly referred to as “glass”) and optional border radius.
/// It can wrap any child widget, making it easy to apply a consistent
/// visual style across the app.
class MobileGlassCard extends StatelessWidget {
  /// The widget displayed inside the glass container.
  final Widget child;

  /// Radius of the card corners.
  final double borderRadius;

  /// The intensity of the blur effect. Higher values produce a stronger
  /// frosted‑glass appearance.
  final double blurSigma;

  /// Background color of the card with opacity. By default it uses a
  /// semi‑transparent white to mimic the classic glass look.
  final Color color;

  const MobileGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurSigma = 12.0,
    this.color = const Color.fromRGBO(255, 255, 255, 0.12),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
