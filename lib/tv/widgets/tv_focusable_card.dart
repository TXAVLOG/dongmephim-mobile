import 'package:flutter/material.dart';
import '../navigation/tv_key_handler.dart';

class TvFocusableCard extends StatefulWidget {
  final Widget child;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final double scaleOnFocus;
  final BorderRadius borderRadius;
  final Color focusBorderColor;
  final Color focusGlowColor;
  final EdgeInsets margin;
  final bool autoScroll;

  const TvFocusableCard({
    super.key,
    required this.child,
    required this.focusNode,
    required this.onTap,
    this.scaleOnFocus = 1.08,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.focusBorderColor = const Color(0xFF737DFD),
    this.focusGlowColor = const Color(0x3D737DFD),
    this.margin = EdgeInsets.zero,
    this.autoScroll = true,
  });

  @override
  State<TvFocusableCard> createState() => _TvFocusableCardState();
}

class _TvFocusableCardState extends State<TvFocusableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleOnFocus).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });

    if (_isFocused) {
      _controller.forward();
      if (widget.autoScroll) {
        // Auto scroll to center of viewport
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
            );
          }
        });
      }
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (TvKeyHandler.isDpadCenter(event)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: widget.focusGlowColor,
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: _isFocused ? widget.focusBorderColor : Colors.transparent,
                  width: 2.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
