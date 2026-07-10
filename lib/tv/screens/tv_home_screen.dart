import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/txa_api.dart';
import '../../services/txa_auth_service.dart';
import '../../services/txa_language.dart';
import '../../utils/txa_toast.dart';
import '../../services/txa_notification_manager.dart';
import '../widgets/tv_focusable_card.dart';
import '../widgets/tv_sidebar.dart';
import '../navigation/tv_focus_system.dart';
import '../services/tv_cache_service.dart';
import 'tv_movie_detail_screen.dart';
import 'tv_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/txa_modal.dart';
import '../widgets/tv_profile_tab.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int _currentTab = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _homeData;

  // Banner details
  List<dynamic> _heroMovies = [];
  int _heroActiveIndex = 0;
  Timer? _heroTimer;
  final PageController _heroPageController = PageController();

  // Scroll controllers
  final ScrollController _pageScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    TxaNotificationManager.instance.init();
    _loadHomeData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    TxaNotificationManager.instance.dispose();
    _pageScrollController.dispose();
    TvFocusSystem.disposeScreen('home_');
    super.dispose();
  }

  List<dynamic> _getList(dynamic section) {
    if (section == null) return [];
    if (section is Map) {
      return section['data'] as List<dynamic>? ?? [];
    }
    if (section is List) {
      return section;
    }
    return [];
  }

  Future<void> _loadHomeData() async {
    // 1. Try reading cache first
    try {
      final cached = await TvCacheService().read('get_home');
      if (cached != null) {
        setState(() {
          _homeData = cached;
          _setupBannerMovie(cached);
          _isLoading = false;
        });
        _checkAndShowWelcomeDpad();
      }
    } catch (_) {}

    // 2. Fetch from API
    try {
      final res = await TxaApi().getHome();
      if (res != null && mounted) {
        await TvCacheService().write('get_home', res);
        setState(() {
          _homeData = res;
          _setupBannerMovie(res);
          _isLoading = false;
        });
        _checkAndShowWelcomeDpad();
      }
    } catch (e) {
      if (mounted && _homeData == null) {
        setState(() => _isLoading = false);
        TxaToast.show(context, TxaLanguage.t('tv_load_home_error'), isError: true);
      }
    }
  }

  void _setupBannerMovie(Map<String, dynamic> res) {
    final sliderList = _getList(res['featured'] ?? res['slider']);
    if (sliderList.isNotEmpty) {
      _heroMovies = sliderList.take(5).toList();
    } else {
      final hotList = _getList(res['TXA_HOT1'] ?? res['hot']);
      _heroMovies = hotList.take(5).toList();
    }
    
    if (_heroMovies.isNotEmpty) {
      _heroActiveIndex = 0;
      _startHeroTimer();
    }
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!mounted || _heroMovies.isEmpty) return;
      final nextIndex = (_heroActiveIndex + 1) % _heroMovies.length;
      _changeHeroSlide(nextIndex);
    });
  }

  void _changeHeroSlide(int index) {
    if (!mounted) return;
    setState(() {
      _heroActiveIndex = index;
    });
    if (_heroPageController.hasClients) {
      _heroPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onMenuSelect(int index) {
    if (index == 5) {
      // Logout
      _handleTvLogout();
      return;
    }
    setState(() {
      _currentTab = index;
    });
  }

  Future<void> _handleTvLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(TxaLanguage.t('tv_logout_confirm_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(TxaLanguage.t('tv_logout_confirm_msg'), style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TvFocusableCard(
            focusNode: TvFocusSystem.getNode('logout_cancel'),
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white12,
              child: Text(TxaLanguage.t('tv_cancel'), style: const TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          TvFocusableCard(
            focusNode: TvFocusSystem.getNode('logout_ok'),
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.redAccent,
              child: Text(TxaLanguage.t('tv_logout'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await TxaAuthService().logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TvLoginScreen()),
      );
    }
  }

  Future<void> _checkAndShowWelcomeDpad() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('tv_has_shown_welcome_dpad_guide') ?? false;
    if (!hasShown) {
      await prefs.setBool('tv_has_shown_welcome_dpad_guide', true);
      _showWelcomeDpadDialog();
    }
  }

  void _showWelcomeDpadDialog() {
    if (!mounted) return;
    
    TxaModal.show(
      context,
      barrierDismissible: false,
      showClose: false,
      title: TxaLanguage.t('tv_dpad_guide_title'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TxaLanguage.t('tv_dpad_guide_welcome'),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.unfold_more_rounded, color: Color(0xFF737DFD), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TxaLanguage.t('tv_dpad_guide_arrows'),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF737DFD), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TxaLanguage.t('tv_dpad_guide_ok'),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_back_rounded, color: Color(0xFF737DFD), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TxaLanguage.t('tv_dpad_guide_back'),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('tv_dpad_guide_hint'),
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TvFocusableCard(
          focusNode: TvFocusSystem.getNode('welcome_dpad_dismiss'),
          onTap: () {
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: const Color(0xFF737DFD),
            child: Text(
              TxaLanguage.t('got_it'),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );

    // Request focus on welcome button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          TvFocusSystem.getNode('welcome_dpad_dismiss').requestFocus();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090A0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF737DFD)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: Row(
        children: [
          // Left Sidebar navigation
          TvSidebar(
            selectedIndex: _currentTab,
            onSelected: _onMenuSelect,
          ),
          
          // Main Content View
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildHomeDashboard();
      case 1:
        return const TvSearchTab();
      case 2:
        return TvCategoryGrid(
          key: const ValueKey('TXA_PB1'),
          type: 'TXA_PB1',
          title: TxaLanguage.t('TXA_PB1'),
        );
      case 3:
        return TvCategoryGrid(
          key: const ValueKey('TXA_PL1'),
          type: 'TXA_PL1',
          title: TxaLanguage.t('TXA_PL1'),
        );
      case 4:
        return const TvProfileTab();
      default:
        return _buildHomeDashboard();
    }
  }

  Widget _buildHomeDashboard() {
    final newMovies = _getList(_homeData?['TXA_NEW1'] ?? _homeData?['new']);
    final hotMovies = _getList(_homeData?['TXA_HOT1'] ?? _homeData?['hot']);
    final animeList = _getList(_homeData?['TXA_HH1']);
    final seriesList = _getList(_homeData?['TXA_PB1'] ?? _homeData?['series']);
    final singleList = _getList(_homeData?['TXA_PL1']);
    final theaterList = _getList(_homeData?['TXA_CR1']);
    final tvShowsList = _getList(_homeData?['TXA_TV1']);

    return SingleChildScrollView(
      controller: _pageScrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FEATURED HERO SLIDER WITH HEADER OVERLAY
          SizedBox(
            height: _heroMovies.isNotEmpty ? 380 : 70,
            child: Stack(
              children: [
                if (_heroMovies.isNotEmpty) _buildHeroSlider(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(),
                ),
              ],
            ),
          ),

          // 2. HORIZONTAL SHELVES - All categories matching mobile
          if (newMovies.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_NEW1'), 'TXA_NEW1', newMovies),

          if (hotMovies.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_HOT1'), 'TXA_HOT1', hotMovies),

          if (animeList.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_HH1'), 'TXA_HH1', animeList),

          if (seriesList.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_PB1'), 'TXA_PB1', seriesList),

          if (singleList.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_PL1'), 'TXA_PL1', singleList),

          if (theaterList.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_CR1'), 'TXA_CR1', theaterList),

          if (tvShowsList.isNotEmpty)
            _buildMovieShelf(TxaLanguage.t('TXA_TV1'), 'TXA_TV1', tvShowsList),
            
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final auth = TxaAuthService();
    final isLoggedIn = auth.isLoggedIn;
    final user = auth.user;
    final name = user?['name'] ?? user?['username'] ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Logo
          Image.asset('assets/dongphim_logo.png', height: 40),
          
          // Right User Profile Avatar / Login Icon
          TvFocusableCard(
            focusNode: TvFocusSystem.getNode('header_profile'),
            scaleOnFocus: 1.1,
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _currentTab = 4; // Switch to Profile tab
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: isLoggedIn
                  ? CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF737DFD),
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    )
                  : const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.account_circle_outlined, color: Colors.white, size: 20),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlider() {
    return SizedBox(
      height: 380,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroPageController,
            itemCount: _heroMovies.length,
            onPageChanged: (index) {
              setState(() {
                _heroActiveIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final movie = _heroMovies[index];
              final title = movie['name'] ?? '';
              final originName = movie['origin_name'] ?? '';
              final thumb = movie['thumb_url'] ?? movie['poster_url'] ?? '';
              final quality = movie['quality'] ?? 'FHD';
              final year = movie['publish_year'] ?? '2026';
              final plot = movie['description'] ?? TxaLanguage.t('tv_no_description');

              final playNode = TvFocusSystem.getNode('hero_play');
              final detailNode = TvFocusSystem.getNode('hero_detail');

              return Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(color: Colors.black),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF090A0F), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: [0.05, 0.65],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF090A0F), Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.15, 0.65],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 24,
                    left: 36,
                    right: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF737DFD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(quality, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(year.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (originName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            originName,
                            style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          plot,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            TvFocusableCard(
                              focusNode: playNode,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                color: const Color(0xFF737DFD),
                                child: Row(
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                                    const SizedBox(width: 6),
                                    Text(TxaLanguage.t('tv_watch_now'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            TvFocusableCard(
                              focusNode: detailNode,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                color: Colors.white.withValues(alpha: 0.1),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(TxaLanguage.t('tv_info'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          if (_heroMovies.length > 1) ...[
            Positioned(
              left: 12,
              top: 170,
              child: TvFocusableCard(
                focusNode: TvFocusSystem.getNode('hero_prev'),
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  final prevIndex = (_heroActiveIndex - 1 + _heroMovies.length) % _heroMovies.length;
                  _changeHeroSlide(prevIndex);
                  _startHeroTimer();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black45,
                  child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 24),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 170,
              child: TvFocusableCard(
                focusNode: TvFocusSystem.getNode('hero_next'),
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  final nextIndex = (_heroActiveIndex + 1) % _heroMovies.length;
                  _changeHeroSlide(nextIndex);
                  _startHeroTimer();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black45,
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovieShelf(String title, String keyPrefix, List<dynamic> movies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 36.0, top: 24.0, bottom: 12.0),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
              final name = movie['name'] ?? '';
              final year = movie['publish_year'] ?? '2026';
              final node = TvFocusSystem.getNode('home_${keyPrefix}_card_$index');

              return Container(
                width: 110,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: TvFocusableCard(
                  focusNode: node,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          width: 110,
                          placeholder: (c, u) => Container(color: Colors.white12),
                          errorWidget: (c, u, e) => Container(color: Colors.white10),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        child: Text(
                          year.toString(),
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  // Profile tab now delegates to TvProfileTab widget
}

class TvCategoryGrid extends StatefulWidget {
  final String type;
  final String title;

  const TvCategoryGrid({
    super.key,
    required this.type,
    required this.title,
  });

  @override
  State<TvCategoryGrid> createState() => _TvCategoryGridState();
}

class _TvCategoryGridState extends State<TvCategoryGrid> {
  final List<dynamic> _movies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    TvFocusSystem.disposeScreen('grid_${widget.type}_');
    super.dispose();
  }

  Future<void> _loadMovies({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _page = 1;
        _movies.clear();
        _hasMore = true;
      });
    }

    try {
      final res = await TxaApi().getType(widget.type, page: _page);
      if (res != null) {
        final List<dynamic> list = res['movies']?['data'] as List? ??
            res['data'] as List? ??
            res['items'] as List? ??
            [];

        if (mounted) {
          setState(() {
            _movies.addAll(list);
            _isLoading = false;
            _isLoadingMore = false;
            _hasMore = list.length >= 10;
            if (list.isNotEmpty) {
              _page++;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
            _hasMore = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 36.0, top: 24.0, bottom: 16.0),
          child: Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF737DFD)))
              : _movies.isEmpty
                  ? Center(child: Text(TxaLanguage.t('no_movies'), style: const TextStyle(color: Colors.white30)))
                  : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _movies.length + (_hasMore ? 5 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _movies.length) {
                          if (!_isLoadingMore && _hasMore) {
                            _loadMovies(loadMore: true);
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF737DFD)),
                              ),
                            ),
                          );
                        }

                        final movie = _movies[index];
                        final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
                        final name = movie['name'] ?? '';
                        final year = movie['publish_year'] ?? movie['year'] ?? '2026';
                        final node = TvFocusSystem.getNode('grid_${widget.type}_card_$index');

                        return TvFocusableCard(
                          focusNode: node,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: CachedNetworkImage(
                                  imageUrl: poster,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (c, u) => Container(color: Colors.white12),
                                  errorWidget: (c, u, e) => Container(color: Colors.white10),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 2.0),
                                child: Text(
                                  year.toString(),
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class TvSearchTab extends StatefulWidget {
  const TvSearchTab({super.key});

  @override
  State<TvSearchTab> createState() => _TvSearchTabState();
}

class _TvSearchTabState extends State<TvSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _hotKeywords = [];
  List<dynamic> _movies = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  String _query = '';
  int _currentPage = 1;
  int _lastPage = 1;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchHotSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    TvFocusSystem.disposeScreen('search_');
    super.dispose();
  }

  Future<void> _fetchHotSearches() async {
    try {
      final list = await TxaApi().getHotSearches();
      if (mounted) {
        setState(() {
          _hotKeywords = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _executeSearch({bool isNewSearch = true}) async {
    if (!mounted) return;
    if (_query.isEmpty) {
      setState(() {
        _movies.clear();
        _isLoading = false;
      });
      return;
    }

    if (isNewSearch) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _movies.clear();
      });
    } else {
      setState(() {
        _isMoreLoading = true;
      });
    }

    try {
      final data = await TxaApi().searchMovies(_query, page: _currentPage);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
          if (data != null) {
            final results = data['data'] as List<dynamic>? ?? [];
            if (isNewSearch) {
              _movies = results;
            } else {
              _movies.addAll(results);
            }
            final pag = data['pagination'];
            if (pag != null) {
              _lastPage = int.tryParse(pag['last_page'].toString()) ?? 1;
            } else {
              _lastPage = 1;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
        });
        _executeSearch(isNewSearch: true);
      }
    });
  }

  void _performImmediateSearch(String keyword) {
    final cleanKeyword = keyword.trim();
    _debounceTimer?.cancel();
    _searchController.text = cleanKeyword;
    setState(() {
      _query = cleanKeyword;
    });
    _executeSearch(isNewSearch: true);
    if (cleanKeyword.isNotEmpty) {
      TxaApi().registerSearchClick(cleanKeyword);
    }
  }

  Future<void> _loadMoreMovies() async {
    _currentPage++;
    await _executeSearch(isNewSearch: false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Header
        Padding(
          padding: const EdgeInsets.only(left: 36.0, top: 24.0, right: 36.0, bottom: 16.0),
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() {});
            },
            child: Builder(
              builder: (context) {
                final hasFocus = Focus.of(context).hasFocus;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: hasFocus ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasFocus ? const Color(0xFF737DFD) : Colors.white10,
                      width: 2,
                    ),
                    boxShadow: hasFocus
                        ? [
                            const BoxShadow(
                              color: Color(0x3D737DFD),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Icon(Icons.search_rounded, color: Colors.white70, size: 24),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: _performImmediateSearch,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: TxaLanguage.t('search_hint'),
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 15),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _movies.clear();
                            });
                          },
                        ),
                    ],
                  ),
                );
              }
            ),
          ),
        ),

        // Main Search Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF737DFD)))
              : _query.isEmpty
                  ? _buildTrendingSection()
                  : _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildTrendingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TxaLanguage.t('search_hot_title'),
            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_hotKeywords.isEmpty)
            const Text(
              'Không có từ khóa hot nào',
              style: TextStyle(color: Colors.white30, fontSize: 14),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_hotKeywords.length, (index) {
                    final item = _hotKeywords[index];
                    final kw = item['keyword'] as String;
                    final node = TvFocusSystem.getNode('search_hot_tag_$index');

                    return TvFocusableCard(
                      focusNode: node,
                      onTap: () => _performImmediateSearch(kw),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: Colors.white.withValues(alpha: 0.05),
                        child: Text(
                          kw,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_movies.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: Colors.white30, size: 48),
            const SizedBox(height: 16),
            Text(
              TxaLanguage.t('search_no_results').replaceAll('%query%', _query),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
        childAspectRatio: 0.65,
      ),
      itemCount: _movies.length + (_currentPage < _lastPage ? 5 : 0),
      itemBuilder: (context, index) {
        if (index >= _movies.length) {
          if (!_isMoreLoading && _currentPage < _lastPage) {
            _loadMoreMovies();
          }
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF737DFD)),
              ),
            ),
          );
        }

        final movie = _movies[index];
        final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
        final name = movie['name'] ?? '';
        final year = movie['publish_year'] ?? movie['year'] ?? '2026';
        final node = TvFocusSystem.getNode('search_result_card_$index');

        return TvFocusableCard(
          focusNode: node,
          onTap: () {
            TxaApi().registerSearchClick(_query, movieId: movie['id']);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (c, u) => Container(color: Colors.white12),
                  errorWidget: (c, u, e) => Container(color: Colors.white10),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 2.0),
                child: Text(
                  year.toString(),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
