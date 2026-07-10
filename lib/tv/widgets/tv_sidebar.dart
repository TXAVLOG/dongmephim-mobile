import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/txa_language.dart';
import '../../services/txa_auth_service.dart';
import '../navigation/tv_focus_system.dart';
import 'tv_focusable_card.dart';

class TvSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const TvSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<TvSidebar> createState() => _TvSidebarState();
}

class _TvSidebarState extends State<TvSidebar> {
  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.home_rounded, 'key': 'tv_menu_home'},
    {'icon': Icons.search_rounded, 'key': 'tv_menu_search'},
    {'icon': Icons.movie_filter_rounded, 'key': 'tv_menu_series'},
    {'icon': Icons.movie_creation_rounded, 'key': 'tv_menu_singles'},
    {'icon': Icons.person_outline_rounded, 'key': 'tv_menu_profile'},
    {'icon': Icons.logout_rounded, 'key': 'tv_menu_logout'},
  ];

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Provider.of<TxaAuthService>(context).isLoggedIn;
    final items = isLoggedIn ? _menuItems : _menuItems.where((item) => item['key'] != 'tv_menu_logout').toList();

    return Container(
      width: 72,
      color: const Color(0xFF0C0D14),
      child: Column(
        children: [
          // TV Logo / Logo icon
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Image.asset(
              'assets/logo.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if logo asset is missing
                return const Icon(
                  Icons.movie_filter_rounded,
                  color: Color(0xFF737DFD),
                  size: 32,
                );
              },
            ),
          ),
          
          // Menu Items List
          Expanded(
            child: Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = widget.selectedIndex == index;
                final node = TvFocusSystem.getNode('sidebar_item_$index');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: _TvSidebarItem(
                    icon: item['icon'] as IconData,
                    labelKey: item['key'] as String,
                    isSelected: isSelected,
                    focusNode: node,
                    onTap: () => widget.onSelected(index),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvSidebarItem extends StatefulWidget {
  final IconData icon;
  final String labelKey;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  const _TvSidebarItem({
    required this.icon,
    required this.labelKey,
    required this.isSelected,
    required this.focusNode,
    required this.onTap,
  });

  @override
  State<_TvSidebarItem> createState() => _TvSidebarItemState();
}

class _TvSidebarItemState extends State<_TvSidebarItem> with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  bool _showTooltip = false;
  Timer? _timer;
  late AnimationController _tooltipController;
  late Animation<double> _tooltipAnimation;

  @override
  void initState() {
    super.initState();
    _tooltipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _tooltipAnimation = CurvedAnimation(
      parent: _tooltipController,
      curve: Curves.easeOutCubic,
    );
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _tooltipController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });

    if (_isFocused) {
      _startTooltip();
    } else {
      _hideTooltip();
    }
  }

  void _startTooltip() {
    _timer?.cancel();
    setState(() {
      _showTooltip = true;
    });
    _tooltipController.forward();

    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isFocused) {
        _tooltipController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showTooltip = false;
            });
          }
        });
      }
    });
  }

  void _hideTooltip() {
    _timer?.cancel();
    _tooltipController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showTooltip = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF737DFD);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        // Sidebar Button
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: TvFocusableCard(
            focusNode: widget.focusNode,
            scaleOnFocus: 1.08,
            borderRadius: BorderRadius.circular(12),
            autoScroll: false,
            onTap: () {
              widget.onTap();
              if (_isFocused) {
                _startTooltip();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? activeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: widget.isSelected ? activeColor : Colors.white60,
                  size: 22,
                ),
              ),
            ),
          ),
        ),

        // Vertical glowing indicator bar for selected item
        if (widget.isSelected)
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

        // Floating Tooltip bubble to the right
        if (_showTooltip)
          Positioned(
            left: 78,
            child: AnimatedBuilder(
              animation: _tooltipAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _tooltipAnimation.value,
                  child: Transform.translate(
                    offset: Offset((1.0 - _tooltipAnimation.value) * -8.0, 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2030),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: Text(
                  TxaLanguage.t(widget.labelKey),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

