import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TxaPlayerCoachmark {
  // Guard against overlapping calls to show() (e.g. double navigation frame).
  static bool _isShowing = false;

  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;

    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('txa_has_shown_player_coachmark') ?? false;
    if (hasShown) return;
    await prefs.setBool('txa_has_shown_player_coachmark', true);

    if (!context.mounted) return;

    _isShowing = true;
    _showStep(context, 0);
  }

  static void _showStep(BuildContext context, int step) {
    if (!context.mounted) {
      _isShowing = false;
      return;
    }

    final List<Map<String, String>> steps = [
      {
        'title': 'coach_player_brightness_title',
        'desc': 'coach_player_brightness_desc',
        'side': 'left', // brightness
      },
      {
        'title': 'coach_player_volume_title',
        'desc': 'coach_player_volume_desc',
        'side': 'right', // volume
      },
      {
        'title': 'coach_player_seek_title',
        'desc': 'coach_player_seek_desc',
        'side': 'both', // double tap
      },
    ];

    if (step >= steps.length) {
      _isShowing = false;
      return;
    }

    final current = steps[step];
    final overlayState = Overlay.of(context);
    final size = MediaQuery.of(context).size;

    late OverlayEntry overlayEntry;

    void goToNext() {
      overlayEntry.remove();
      _showStep(context, step + 1);
    }

    void dismissAll() {
      overlayEntry.remove();
      _isShowing = false;
    }

    overlayEntry = OverlayEntry(
      builder: (ctx) => _CoachmarkStep(
        current: current,
        step: step,
        totalSteps: steps.length,
        screenSize: size,
        onNext: goToNext,
        onSkip: dismissAll,
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _CoachmarkStep extends StatefulWidget {
  final Map<String, String> current;
  final int step;
  final int totalSteps;
  final Size screenSize;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachmarkStep({
    required this.current,
    required this.step,
    required this.totalSteps,
    required this.screenSize,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<_CoachmarkStep> createState() => _CoachmarkStepState();
}

class _CoachmarkStepState extends State<_CoachmarkStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _green = Color(0xFF00FF87);
  static const Color _orange = Color(0xFFFF7B00);

  Color get _accentColor {
    switch (widget.current['side']) {
      case 'left':
        return _cyan;
      case 'right':
        return _green;
      default:
        return _orange;
    }
  }

  IconData get _titleIcon {
    switch (widget.current['side']) {
      case 'left':
        return Icons.lightbulb_outline_rounded;
      case 'right':
        return Icons.volume_up_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  Alignment get _cardAlignment {
    switch (widget.current['side']) {
      case 'left':
        return const Alignment(0.65, 0.0);
      case 'right':
        return const Alignment(-0.65, 0.0);
      default:
        return const Alignment(0.0, 0.6);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateOutThen(VoidCallback action) async {
    if (!mounted) {
      action();
      return;
    }
    await _controller.reverse();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.current['side'];
    final accent = _accentColor;
    final width = widget.screenSize.width;
    final height = widget.screenSize.height;

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          // Dark backdrop
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.8)),
          ),

          // Neon highlight panels
          if (side == 'left')
            _HighlightPanel(
              alignmentLeft: true,
              width: width * 0.5,
              color: _cyan,
              icon: Icons.swipe_vertical_rounded,
              label: TxaLanguage.t('tv_hint_volume') == 'Âm lượng'
                  ? 'Độ sáng'
                  : 'Brightness',
            ),

          if (side == 'right')
            _HighlightPanel(
              alignmentLeft: false,
              width: width * 0.5,
              color: _green,
              icon: Icons.swipe_vertical_rounded,
              label: TxaLanguage.t('tv_hint_volume') == 'Âm lượng'
                  ? 'Âm lượng'
                  : 'Volume',
            ),

          if (side == 'both') ...[
            Positioned(
              left: 20,
              top: height * 0.25,
              bottom: height * 0.25,
              width: width * 0.35,
              child: const _DoubleTapZone(
                color: _orange,
                icon: Icons.replay_10_rounded,
              ),
            ),
            Positioned(
              right: 20,
              top: height * 0.25,
              bottom: height * 0.25,
              width: width * 0.35,
              child: const _DoubleTapZone(
                color: _orange,
                icon: Icons.forward_10_rounded,
              ),
            ),
          ],

          // Neon Content Card
          Align(
            alignment: _cardAlignment,
            child: ScaleTransition(
              scale: _scale,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0E15).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_titleIcon, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              TxaLanguage.t(widget.current['title']!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _animateOutThen(widget.onSkip),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white38,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        TxaLanguage.t(widget.current['desc']!),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.step + 1}/${widget.totalSteps}',
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _animateOutThen(widget.onNext),
                            style: TextButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              widget.step == widget.totalSteps - 1
                                  ? TxaLanguage.t('got_it')
                                  : TxaLanguage.t('next'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightPanel extends StatefulWidget {
  final bool alignmentLeft;
  final double width;
  final Color color;
  final IconData icon;
  final String label;

  const _HighlightPanel({
    required this.alignmentLeft,
    required this.width,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  State<_HighlightPanel> createState() => _HighlightPanelState();
}

class _HighlightPanelState extends State<_HighlightPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _handController;
  late final Animation<double> _handOffset;
  late final Animation<double> _handFade;

  @override
  void initState() {
    super.initState();
    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _handOffset = Tween<double>(begin: -16, end: 16).animate(
      CurvedAnimation(parent: _handController, curve: Curves.easeInOut),
    );
    _handFade = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _handController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _handController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.alignmentLeft ? 0 : null,
      right: widget.alignmentLeft ? null : 0,
      top: 0,
      bottom: 0,
      width: widget.width,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.color.withValues(alpha: 0.8),
            width: 2,
          ),
          color: widget.color.withValues(alpha: 0.05),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Faint static swipe-path icon behind the moving hand.
              Icon(
                widget.icon,
                color: widget.color.withValues(alpha: 0.25),
                size: 54,
              ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: _handController,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(0, _handOffset.value),
                  child: Opacity(opacity: _handFade.value, child: child),
                ),
                child: Icon(
                  Icons.pan_tool_alt_rounded,
                  color: widget.color,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoubleTapZone extends StatefulWidget {
  final Color color;
  final IconData icon;

  const _DoubleTapZone({required this.color, required this.icon});

  @override
  State<_DoubleTapZone> createState() => _DoubleTapZoneState();
}

class _DoubleTapZoneState extends State<_DoubleTapZone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;

  // Two quick taps then a pause, looping — mimics a double-tap gesture.
  late final Animation<double> _handScale;
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Fade;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Fade;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _handScale = _buildHandScale();
    _ring1Scale = _buildRingScale(startInterval: 0.0);
    _ring1Fade = _buildRingFade(startInterval: 0.0);
    _ring2Scale = _buildRingScale(startInterval: 0.2);
    _ring2Fade = _buildRingFade(startInterval: 0.2);
  }

  Animation<double> _buildHandScale() {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.72), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.0), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.72), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
    ]).animate(_tapController);
  }

  // A ripple ring that expands + fades starting at [startInterval] within
  // the loop, so the two rings fire just after each "tap".
  Animation<double> _buildRingScale({required double startInterval}) {
    final end = (startInterval + 0.18).clamp(0.0, 1.0);
    return Tween<double>(begin: 0.4, end: 1.6).animate(
      CurvedAnimation(
        parent: _tapController,
        curve: Interval(startInterval, end, curve: Curves.easeOut),
      ),
    );
  }

  Animation<double> _buildRingFade({required double startInterval}) {
    final end = (startInterval + 0.18).clamp(0.0, 1.0);
    return Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _tapController,
        curve: Interval(startInterval, end, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  Widget _buildRing(Animation<double> scale, Animation<double> fade) {
    return AnimatedBuilder(
      animation: _tapController,
      builder: (ctx, child) => Opacity(
        opacity: fade.value,
        child: Transform.scale(
          scale: scale.value,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.6),
          width: 1.5,
        ),
        color: widget.color.withValues(alpha: 0.03),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildRing(_ring1Scale, _ring1Fade),
            _buildRing(_ring2Scale, _ring2Fade),
            AnimatedBuilder(
              animation: _tapController,
              builder: (ctx, child) => Transform.scale(
                scale: _handScale.value,
                child: child,
              ),
              child: Icon(widget.icon, color: widget.color, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}