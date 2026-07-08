import 'package:flutter/material.dart';

class AttackEvent {
  final String id;
  final bool isFromMe;
  final String type; // e.g., 'slash', 'fire', 'ice', 'stun', 'poison', 'shatter', 'heal'

  AttackEvent({
    required this.id,
    required this.isFromMe,
    this.type = 'slash',
  });
}

class AttackEffectOverlay extends StatefulWidget {
  final List<AttackEvent> events;
  final Widget child;

  const AttackEffectOverlay({
    super.key,
    required this.events,
    required this.child,
  });

  @override
  State<AttackEffectOverlay> createState() => _AttackEffectOverlayState();
}

class _AttackEffectOverlayState extends State<AttackEffectOverlay> {
  final Map<String, AttackEvent> _activeEvents = {};

  @override
  void didUpdateWidget(AttackEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Temukan event baru
    final newEvents = widget.events.where((e) => 
        !oldWidget.events.any((old) => old.id == e.id)).toList();
        
    for (var event in newEvents) {
      _triggerEffect(event);
    }
  }

  void _triggerEffect(AttackEvent event) {
    setState(() {
      _activeEvents[event.id] = event;
    });
    
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _activeEvents.remove(event.id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            ..._activeEvents.values.map((event) => _AnimatedAttackEffect(
              key: ValueKey(event.id),
              event: event,
              screenWidth: constraints.maxWidth,
            )),
          ],
        );
      },
    );
  }
}

class _AnimatedAttackEffect extends StatefulWidget {
  final AttackEvent event;
  final double screenWidth;

  const _AnimatedAttackEffect({
    super.key,
    required this.event,
    required this.screenWidth,
  });

  @override
  State<_AnimatedAttackEffect> createState() => _AnimatedAttackEffectState();
}

class _AnimatedAttackEffectState extends State<_AnimatedAttackEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xPosition;
  late Animation<double> _yPosition;
  late Animation<double> _opacity;
  late Animation<double> _rotation;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Slightly longer for dynamic feel
    );

    // Calculate dynamic X positions
    double meX = 90.0; // Left character avatar center
    double enemyX = widget.screenWidth > 150 ? widget.screenWidth - 130.0 : 250.0; // Right character avatar center

    double startX = widget.event.isFromMe ? meX : enemyX;
    double endX = widget.event.isFromMe ? enemyX : meX;
    double startY = 100.0;
    double endY = 100.0;
    bool isSupport = false;

    // Special logic for support/self-cast effects like heal
    if (widget.event.type == 'heal' || widget.event.type == 'shield' || widget.event.type == 'regen') {
      startX = widget.event.isFromMe ? meX : enemyX;
      endX = startX; // Don't move horizontally
      startY = 80.0; // Start slightly lower
      endY = 180.0; // Move up higher
      isSupport = true;
    }

    _xPosition = Tween<double>(begin: startX, end: endX).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    
    if (isSupport) {
      _yPosition = Tween<double>(begin: startY, end: endY).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
    } else {
      // Parabolic arc for projectiles
      _yPosition = TweenSequence([
        TweenSequenceItem(tween: Tween<double>(begin: startY, end: startY + 80.0).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 1),
        TweenSequenceItem(tween: Tween<double>(begin: startY + 80.0, end: endY).chain(CurveTween(curve: Curves.easeInQuad)), weight: 1),
      ]).animate(_controller);
    }

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 65),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.4), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.4, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 20),
    ]).animate(_controller);

    _rotation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildEffectGraphic() {
    IconData icon = Icons.flash_on; // Default slash
    Color color = Colors.yellowAccent;
    double baseAngle = widget.event.isFromMe ? 1.57 : -1.57; // Putar arah standar
    bool shouldRotate = false;
    double size = 50;

    switch (widget.event.type) {
      case 'fire':
      case 'fire_blast':
        icon = Icons.local_fire_department;
        color = Colors.redAccent;
        baseAngle = widget.event.isFromMe ? 1.57 : -1.57;
        break;
      case 'ice':
      case 'frost_nova':
        icon = Icons.ac_unit;
        color = Colors.lightBlueAccent;
        baseAngle = 0;
        shouldRotate = true; // Ice shards spin
        break;
      case 'stun':
      case 'thunder_strike':
        icon = Icons.bolt;
        color = Colors.yellow;
        baseAngle = 0;
        size = 60;
        break;
      case 'poison':
      case 'poison_dart':
        icon = Icons.coronavirus;
        color = Colors.purpleAccent;
        baseAngle = widget.event.isFromMe ? 1.57 : -1.57;
        shouldRotate = true;
        size = 45;
        break;
      case 'shatter':
        icon = Icons.broken_image;
        color = Colors.orangeAccent;
        baseAngle = 0;
        shouldRotate = true;
        break;
      case 'heal':
      case 'healing_wind':
      case 'regen':
        icon = Icons.favorite;
        color = Colors.pinkAccent;
        baseAngle = 0;
        size = 40;
        break;
      case 'shield':
        icon = Icons.shield;
        color = Colors.blueAccent;
        baseAngle = 0;
        size = 60;
        break;
      default: // slash
        icon = Icons.flash_on;
        color = Colors.yellowAccent;
        baseAngle = widget.event.isFromMe ? 1.57 : -1.57;
    }

    Widget graphic = Icon(
      icon,
      color: color,
      size: size,
      shadows: [
        Shadow(
          color: color.withValues(alpha: 0.8),
          blurRadius: 15,
          offset: const Offset(0, 0),
        )
      ],
    );

    if (shouldRotate) {
      graphic = AnimatedBuilder(
        animation: _rotation,
        builder: (context, child) {
          return Transform.rotate(
            angle: baseAngle + (_rotation.value * 3.14159),
            child: child,
          );
        },
        child: graphic,
      );
    } else {
      graphic = Transform.rotate(
        angle: baseAngle,
        child: graphic,
      );
    }

    return graphic;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_xPosition.value, -_yPosition.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            ),
          );
        },
        child: _buildEffectGraphic(),
      ),
    );
  }
}
