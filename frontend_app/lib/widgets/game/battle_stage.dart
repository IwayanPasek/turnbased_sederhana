import 'package:flutter/material.dart';
import '../../models/player_state.dart';
import 'battle_hud.dart';
import 'battle_character.dart';
import 'vfx_overlay.dart';
import 'attack_effect_overlay.dart';

class BattleStage extends StatefulWidget {
  final String myName;
  final String enemyName;
  final String? myTitle;
  final String? enemyTitle;
  final PlayerState myState;
  final PlayerState enemyState;
  final bool isMyTurn;
  final String? myAnimationTrigger;
  final String? enemyAnimationTrigger;
  final List<VFXEffect> myVfxEffects;
  final List<VFXEffect> enemyVfxEffects;

  const BattleStage({
    super.key,
    required this.myName,
    required this.enemyName,
    this.myTitle,
    this.enemyTitle,
    required this.myState,
    required this.enemyState,
    required this.isMyTurn,
    this.myAnimationTrigger,
    this.enemyAnimationTrigger,
    this.myVfxEffects = const [],
    this.enemyVfxEffects = const [],
  });

  @override
  State<BattleStage> createState() => _BattleStageState();
}

class _BattleStageState extends State<BattleStage> with TickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  
  late AnimationController _stageShakeController;
  late Animation<double> _stageShakeAnimation;
  
  List<AttackEvent> _attackEvents = [];

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flashAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.0), weight: 2),
    ]).animate(_flashController);
    
    _stageShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _stageShakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _stageShakeController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(BattleStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldFlash = false;
    if (widget.myAnimationTrigger != oldWidget.myAnimationTrigger &&
        widget.myAnimationTrigger != null &&
        widget.myAnimationTrigger!.startsWith('hit')) {
      shouldFlash = true;
    }
    // Optional: flash on enemy hit too? Usually screen flashes only when YOU get hit for better feedback
    if (shouldFlash) {
      _flashController.forward(from: 0);
      _stageShakeController.forward(from: 0);
    }
    
    // Attack Effects
    if (widget.myAnimationTrigger != oldWidget.myAnimationTrigger &&
        widget.myAnimationTrigger != null &&
        widget.myAnimationTrigger!.startsWith('attack_')) {
      final parts = widget.myAnimationTrigger!.split('_');
      final type = parts.length > 1 ? parts[1] : 'slash';
      setState(() {
        _attackEvents = List.from(_attackEvents)
          ..add(AttackEvent(
            id: widget.myAnimationTrigger!,
            isFromMe: true,
            type: type,
          ));
      });
    }

    if (widget.enemyAnimationTrigger != oldWidget.enemyAnimationTrigger &&
        widget.enemyAnimationTrigger != null &&
        widget.enemyAnimationTrigger!.startsWith('attack_')) {
      final parts = widget.enemyAnimationTrigger!.split('_');
      final type = parts.length > 1 ? parts[1] : 'slash';
      setState(() {
        _attackEvents = List.from(_attackEvents)
          ..add(AttackEvent(
            id: widget.enemyAnimationTrigger!,
            isFromMe: false,
            type: type,
          ));
      });
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    _stageShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _stageShakeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_stageShakeAnimation.value, _stageShakeAnimation.value / 2),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
      // Use double.infinity so it fills the Expanded parent in GameScreen
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/bg_arena.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black38, BlendMode.darken),
        ),
      ),
      child: Stack(
        children: [
          // Background Grid / Floor
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // Left Character (Me)
          Positioned(
            left: 40,
            bottom: 40,
            child: BattleCharacter(
              isMe: true,
              animationTrigger: widget.myAnimationTrigger,
              vfxEffects: widget.myVfxEffects,
              avatarStyle: widget.myState.avatarStyle,
              isDead: widget.myState.hp <= 0,
              statusEffects: widget.myState.statusEffects,
            ),
          ),

          // Right Character (Enemy)
          Positioned(
            right: 40,
            bottom: 40,
            child: BattleCharacter(
              isMe: false,
              animationTrigger: widget.enemyAnimationTrigger,
              vfxEffects: widget.enemyVfxEffects,
              avatarStyle: widget.enemyState.avatarStyle,
              isDead: widget.enemyState.hp <= 0,
              statusEffects: widget.enemyState.statusEffects,
            ),
          ),

          // Damage Flash Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashAnimation,
                builder: (context, child) {
                  return Container(
                    color: Colors.red.withOpacity(_flashAnimation.value),
                  );
                },
              ),
            ),
          ),

          // HUD overlay at the top of the stage
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: BattleHUD(
              myName: widget.myName,
              enemyName: widget.enemyName,
              myTitle: widget.myTitle,
              enemyTitle: widget.enemyTitle,
              myState: widget.myState,
              enemyState: widget.enemyState,
              isMyTurn: widget.isMyTurn,
            ),
          ),
          
          // Attack Effects Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AttackEffectOverlay(
                events: _attackEvents,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
