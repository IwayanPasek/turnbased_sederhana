import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vfx_overlay.dart';
import '../../models/player_state.dart';

class BattleCharacter extends StatefulWidget {
  final bool isMe;
  final String? animationTrigger;
  final List<VFXEffect> vfxEffects;
  final String avatarStyle;
  final bool isDead;
  final List<StatusEffect> statusEffects;

  const BattleCharacter({
    super.key,
    required this.isMe,
    this.animationTrigger,
    this.vfxEffects = const [],
    this.avatarStyle = 'default',
    this.isDead = false,
    this.statusEffects = const [],
  });

  @override
  State<BattleCharacter> createState() => _BattleCharacterState();
}

class _BattleCharacterState extends State<BattleCharacter> with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _redFlashAnimation;

  late AnimationController _dashController;
  late Animation<double> _dashXAnimation;
  late Animation<double> _dashYAnimation;
  late Animation<double> _dashRotationAnimation;

  late AnimationController _idleController;
  late Animation<double> _idleYAnimation;
  late Animation<double> _idleScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Idle Animation (Breathing effect)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _idleYAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine),
    );
    _idleScaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine),
    );

    // Shake Animation (Hit)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
    
    _redFlashAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.6), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 0.0), weight: 4),
    ]).animate(_shakeController);

    // Dash Animation (Attack) - Dash forward then back with a slight jump and rotation
    _dashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // If it's me (left), dash right (positive X). If enemy (right), dash left (negative X).
    double dashDistance = widget.isMe ? 120.0 : -120.0;
    double rotationAngle = widget.isMe ? 0.15 : -0.15;

    _dashXAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: dashDistance), weight: 3),
      TweenSequenceItem(tween: Tween(begin: dashDistance, end: dashDistance), weight: 2), // pause slightly at apex
      TweenSequenceItem(tween: Tween(begin: dashDistance, end: 0.0), weight: 5),
    ]).animate(CurvedAnimation(parent: _dashController, curve: Curves.easeOut));
    
    _dashYAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -30.0), weight: 3),
      TweenSequenceItem(tween: Tween(begin: -30.0, end: -30.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -30.0, end: 0.0), weight: 5),
    ]).animate(CurvedAnimation(parent: _dashController, curve: Curves.easeInOut));
    
    _dashRotationAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: rotationAngle), weight: 3),
      TweenSequenceItem(tween: Tween(begin: rotationAngle, end: rotationAngle), weight: 2),
      TweenSequenceItem(tween: Tween(begin: rotationAngle, end: 0.0), weight: 5),
    ]).animate(CurvedAnimation(parent: _dashController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(BattleCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationTrigger != oldWidget.animationTrigger && widget.animationTrigger != null) {
      if (widget.animationTrigger!.startsWith('hit')) {
        _shakeController.forward(from: 0);
        if (widget.isMe) HapticFeedback.heavyImpact();
      } else if (widget.animationTrigger!.startsWith('attack')) {
        _dashController.forward(from: 0);
        if (widget.isMe) HapticFeedback.mediumImpact();
      }
    }
    
    // Stop idle animation if dead
    if (widget.isDead) {
      _idleController.stop();
    } else if (!_idleController.isAnimating) {
      _idleController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _dashController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shakeController, _dashController, _idleController]),
      builder: (context, child) {
        String state = 'idle';
        if (widget.isDead) {
          state = 'dead';
        } else if (_shakeController.isAnimating) {
          state = 'hurt';
        } else if (_dashController.isAnimating) {
          state = 'attack';
        }

        Widget image = Image.asset(
          'assets/avatars/${widget.avatarStyle}_$state.png',
          width: 100,
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/avatars/default_$state.png',
              width: 100,
              height: 140,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const SizedBox(
                width: 100, height: 140, 
                child: Center(child: Icon(Icons.person, color: Colors.white, size: 50)),
              ),
            );
          },
        );

        if (!widget.isMe) {
          image = Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // Flip horizontally
            child: image,
          );
        }
        
        // Add red flash when hurt
        if (_shakeController.isAnimating) {
           image = ColorFiltered(
             colorFilter: ColorFilter.mode(
               Colors.red.withValues(alpha: _redFlashAnimation.value), 
               BlendMode.srcATop
             ),
             child: image,
           );
        }

        // Apply persistent status overlays
        if (widget.statusEffects.isNotEmpty) {
           List<Widget> statusIcons = [];
           for (var effect in widget.statusEffects) {
              final name = effect.name.toUpperCase();
              if (name == 'BURN') {
                 statusIcons.add(const Positioned(bottom: 0, child: Icon(Icons.local_fire_department, color: Colors.orange, size: 40)));
              } else if (name == 'STUN') {
                 statusIcons.add(const Positioned(top: -10, child: Icon(Icons.bolt, color: Colors.yellowAccent, size: 40)));
              } else if (name == 'SHIELD') {
                 statusIcons.add(Positioned.fill(child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.6), width: 4)))));
              } else if (name == 'FREEZE') {
                 statusIcons.add(Positioned.fill(child: Container(color: Colors.lightBlueAccent.withValues(alpha: 0.3))));
              } else if (name == 'POISON') {
                 statusIcons.add(const Positioned(top: 20, right: 0, child: Icon(Icons.coronavirus, color: Colors.purpleAccent, size: 30)));
              } else if (name == 'REGEN') {
                 statusIcons.add(const Positioned(top: 20, left: 0, child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 30)));
              }
           }
           if (statusIcons.isNotEmpty) {
              image = Stack(
                 clipBehavior: Clip.none,
                 alignment: Alignment.center,
                 children: [
                    image,
                    ...statusIcons,
                 ]
              );
           }
        }
        
        double currentXOffset = _shakeAnimation.value + _dashXAnimation.value;
        double currentYOffset = _dashYAnimation.value;
        double currentScale = 1.0;
        
        // Apply idle animation only when not attacking or getting hurt
        if (!_dashController.isAnimating && !_shakeController.isAnimating && !widget.isDead) {
          currentYOffset += _idleYAnimation.value;
          currentScale = _idleScaleAnimation.value;
        }

        Widget characterWidget = Transform.translate(
          offset: Offset(currentXOffset, currentYOffset),
          child: Transform.scale(
            scale: currentScale,
            child: Transform.rotate(
              angle: _dashRotationAnimation.value,
              child: image,
            ),
          ),
        );

        return VFXOverlay(
          effects: widget.vfxEffects,
          child: characterWidget,
        );
      },
    );
  }
}

