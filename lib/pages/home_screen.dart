import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_favorite_manager.dart';
import '../services/txa_notification_manager.dart';
import '../widgets/txa_nav.dart';
import '../widgets/txa_drawer.dart';
import '../utils/txa_toast.dart';
import 'txa_log_viewer_screen.dart';
import 'txa_notification_screen.dart';
import 'txa_movie_detail_screen.dart';
import 'txa_search_tab.dart';
import 'txa_profile_screen.dart';
import 'txa_schedule_tab.dart';
import '../widgets/txa_coachmark.dart';
import '../services/txa_play_update_service.dart';
import '../utils/txa_movie_ranker.dart';

ImageProvider? _getAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:image/')) {
    try {
      final base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return null;
    }
  }
  return CachedNetworkImageProvider(avatarUrl);
}

class HomeScreen extends StatefulWidget {
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastPressedAt;

  List<Widget> get _tabs => [
    const HomeTab(),
    const SearchTab(),
    const TxaScheduleTab(),
    const TxaLogViewerScreen(),
    const TxaProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    TxaNotificationManager.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TxaPlayUpdateService.checkBackgroundUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    TxaNotificationManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<TxaLanguage>(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }
        
        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          if (mounted) {
            TxaToast.show(context, TxaLanguage.t('press_back_again'));
          }
          return;
        }
        
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: HomeScreen.scaffoldKey,
        backgroundColor: TxaTheme.primaryBg,
        drawer: TxaDrawer(
          onSelectTab: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        body: Stack(
          children: [
            // Background ambient gradient glow
            Positioned.fill(
              child: Container(
                color: TxaTheme.primaryBg,
              ),
            ),
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TxaTheme.accent.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: TxaTheme.accent.withValues(alpha: 0.12),
                      blurRadius: 100,
                      spreadRadius: 100,
                    ),
                  ],
                ),
              ),
            ),

            // Main Screen Tabs
            Positioned.fill(
              child: _tabs[_currentIndex],
            ),

            // Custom Floating Glass Bottom Navigation Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TxaNav(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<Map<String, dynamic>?> _homeDataFuture;
  String _selectedCategoryKey = 'ALL';
  String? _selectedCountryKey;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = TxaApi().getHome();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TxaCoachmark.show(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<TxaLanguage>(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _homeDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: TxaTheme.accent),
            );
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('error_loading_data'),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _homeDataFuture = TxaApi().getHome();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(TxaLanguage.t('retry')),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          
          List<dynamic> getList(dynamic section) {
            if (section is Map) {
              return section['data'] as List<dynamic>? ?? [];
            }
            if (section is List) {
              return section;
            }
            return [];
          }

          // Parse sections
          final sliderList = getList(data['featured'] ?? data['slider']);
          final rawNewMovies = getList(data['TXA_NEW1']);
          final rawHotMovies = getList(data['TXA_HOT1']);
          final rawAnimeList = getList(data['TXA_HH1']);
          final rawSeriesList = getList(data['TXA_PB1']);
          final rawSingleList = getList(data['TXA_PL1']);
          final rawTheaterList = getList(data['TXA_CR1']);
          final rawTvShowsList = getList(data['TXA_TV1']);

          // Helper to filter by country
          List<dynamic> filterByCountry(List<dynamic> list) {
            if (_selectedCountryKey == null) return list;
            final keyword = _selectedCountryKey!.toLowerCase();
            return list.where((m) {
              final country = (m['country'] ?? m['region'] ?? '').toString().toLowerCase();
              return country.contains(keyword);
            }).toList();
          }

          final newMovies = filterByCountry(rawNewMovies);
          final hotMovies = filterByCountry(rawHotMovies);
          final animeList = filterByCountry(rawAnimeList);
          final seriesList = filterByCountry(rawSeriesList);
          final singleList = filterByCountry(rawSingleList);
          final theaterList = filterByCountry(rawTheaterList);
          final tvShowsList = filterByCountry(rawTvShowsList);

          // Build Chinese Masterpieces
          final allMovies = <dynamic>{
            ...rawNewMovies, ...rawHotMovies, ...rawAnimeList, ...rawSeriesList, ...rawSingleList, ...rawTheaterList, ...rawTvShowsList
          }.toList();
          final chineseMovies = allMovies.where((m) {
            final country = (m['country'] ?? m['region'] ?? '').toString().toLowerCase();
            return country.contains('trung quốc') || country.contains('china');
          }).toList();
          final sortedChineseMovies = TxaMovieRanker.sortMovies(chineseMovies).take(15).toList();

          // Get selected list for specific category view (Vertical Grid top-to-bottom)
          List<dynamic> selectedCategoryMovies = [];
          if (_selectedCategoryKey == 'TXA_NEW1') {
            selectedCategoryMovies = newMovies;
          } else if (_selectedCategoryKey == 'TXA_HOT1') {
            selectedCategoryMovies = hotMovies;
          } else if (_selectedCategoryKey == 'TXA_PB1') {
            selectedCategoryMovies = seriesList;
          } else if (_selectedCategoryKey == 'TXA_PL1') {
            selectedCategoryMovies = singleList;
          } else if (_selectedCategoryKey == 'TXA_HH1') {
            selectedCategoryMovies = animeList;
          } else if (_selectedCategoryKey == 'TXA_CR1') {
            selectedCategoryMovies = theaterList;
          } else if (_selectedCategoryKey == 'TXA_TV1') {
            selectedCategoryMovies = tvShowsList;
          } else if (_selectedCategoryKey == 'TXA_CN1') {
            selectedCategoryMovies = sortedChineseMovies;
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Home Premium Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 10,
                    right: 16,
                    bottom: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: TxaCoachKeys.menuKey,
                            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                            onPressed: () => HomeScreen.scaffoldKey.currentState?.openDrawer(),
                          ),
                          const SizedBox(width: 4),
                          Image.asset('assets/dongphim_logo.png', height: 32),
                          const SizedBox(width: 10),
                          Text(
                            TxaLanguage.t('app_name'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (ctx) => const NotificationScreen()),
                              );
                              if (!context.mounted) return;
                              if (result == 'go_to_profile') {
                                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                                if (homeState != null) {
                                  homeState.setState(() {
                                    homeState._currentIndex = 4;
                                  });
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          Consumer<TxaAuthService>(
                            builder: (context, auth, child) {
                              final initials = auth.isLoggedIn && auth.user?['name'] != null && auth.user!['name'].toString().isNotEmpty
                                  ? auth.user!['name'].toString()[0].toUpperCase()
                                  : '';
                              
                              return GestureDetector(
                                onTap: () {
                                  final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                                  if (homeState != null) {
                                    homeState.setState(() {
                                      homeState._currentIndex = 4;
                                    });
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: TxaTheme.accent, width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: auth.isLoggedIn ? TxaTheme.secondaryBg : Colors.white.withValues(alpha: 0.08),
                                    backgroundImage: auth.isLoggedIn ? _getAvatarProvider(auth.user?['avatar_url']?.toString()) : null,
                                    child: auth.isLoggedIn
                                        ? ((auth.user?['avatar_url'] == null || auth.user!['avatar_url'].toString().isEmpty)
                                            ? Text(
                                                initials,
                                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                              )
                                            : null)
                                        : const Icon(
                                            Icons.person_outline_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Continue Watching Interactive Shelf
              SliverToBoxAdapter(
                child: _buildContinueWatchingShelf(),
              ),

              // Category Quick Filter Chips
              SliverToBoxAdapter(
                child: _buildCategoryQuickFilters(),
              ),

              // Country Filters
              SliverToBoxAdapter(
                child: _buildCountryFilters(),
              ),

              // Hero spotlight banner (Only on ALL view)
              if (sliderList.isNotEmpty && _selectedCategoryKey == 'ALL')
                SliverToBoxAdapter(
                  child: _buildHeroSpotlight(sliderList.first),
                ),

              // Shelves List (Horizontal on ALL) OR Vertical Grid (Top-to-Bottom on specific Category)
              if (_selectedCategoryKey == 'ALL')
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (newMovies.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_NEW1'), newMovies, 'TXA_NEW1'),
                      if (hotMovies.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_HOT1'), hotMovies, 'TXA_HOT1'),
                      if (animeList.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_HH1'), animeList, 'TXA_HH1'),
                      if (seriesList.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_PB1'), seriesList, 'TXA_PB1'),
                      if (singleList.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_PL1'), singleList, 'TXA_PL1'),
                      if (sortedChineseMovies.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('txa_category_chinese_masterpieces'), sortedChineseMovies, 'TXA_CN1'),
                      if (theaterList.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_CR1'), theaterList, 'TXA_CR1'),
                      if (tvShowsList.isNotEmpty)
                        _buildMovieShelf(TxaLanguage.t('TXA_TV1'), tvShowsList, 'TXA_TV1'),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 100),
                  sliver: selectedCategoryMovies.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                TxaLanguage.t('no_movies_found'),
                                style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
                              ),
                            ),
                          ),
                        )
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.55,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 10,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final movie = selectedCategoryMovies[index];
                              return _buildGridMovieCard(movie);
                            },
                            childCount: selectedCategoryMovies.length,
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroSpotlight(dynamic movie) {
    final thumbUrl = movie['thumb_url'] ?? '';
    final name = movie['name'] ?? '';
    final originName = movie['origin_name'] ?? '';
    final quality = movie['quality'] ?? 'FHD';
    final lang = movie['lang'] ?? 'Vietsub';

    return Container(
      key: TxaCoachKeys.heroKey,
      height: 230,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TxaTheme.liquidGlassPill(
        radius: 20,
        child: Stack(
          children: [
            // Spotlight thumb background
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(color: TxaTheme.cardBg),
                ),
              ),
            ),
            // Bottom shadow overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Text info & button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: TxaTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          quality,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang,
                        style: const TextStyle(
                          color: TxaTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    originName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => MovieDetailScreen(slug: movie['slug'] ?? ''),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      TxaLanguage.t('watch_now'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueWatchingShelf() {
    return FutureBuilder<List<dynamic>>(
      future: TxaApi().getWatchHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final lastMovie = snapshot.data!.first;
        final movieName = (lastMovie['movie_name'] ?? lastMovie['name'] ?? '').toString();
        final slug = (lastMovie['movie_slug'] ?? lastMovie['slug'] ?? '').toString();
        final thumbUrl = (lastMovie['movie_thumb'] ?? lastMovie['poster_url'] ?? lastMovie['thumb_url'] ?? lastMovie['thumb'] ?? '').toString();

        if (movieName.isEmpty || slug.isEmpty) {
          return const SizedBox.shrink();
        }

        String rawEp = (lastMovie['episode_name'] ?? lastMovie['episode_current'] ?? lastMovie['episode'] ?? '').toString();
        String epDisplay = '';
        if (rawEp.isNotEmpty) {
          final lower = rawEp.toLowerCase().trim();
          if (lower.startsWith('tập') || lower.startsWith('ep') || lower.startsWith('tâp')) {
            epDisplay = rawEp;
          } else {
            epDisplay = TxaLanguage.t('episode_label').replaceAll('%n%', rawEp);
          }
        }

        double progress = 0.0;
        final currentTime = double.tryParse(lastMovie['current_time']?.toString() ?? '0') ?? 0;
        final duration = double.tryParse(lastMovie['duration']?.toString() ?? '0') ?? 0;
        if (duration > 0) {
          progress = (currentTime / duration).clamp(0.05, 1.0);
        } else {
          progress = 0.35;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TxaTheme.liquidGlassPill(
            radius: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: TxaTheme.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
                gradient: LinearGradient(
                  colors: [
                    TxaTheme.secondaryBg.withValues(alpha: 0.9),
                    TxaTheme.cardBg.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 58,
                      height: 78,
                      child: thumbUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumbUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: TxaTheme.cardBg),
                              errorWidget: (context, url, error) => Container(
                                color: TxaTheme.cardBg,
                                child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 24),
                              ),
                            )
                          : Container(
                              color: TxaTheme.cardBg,
                              child: const Icon(Icons.movie_rounded, color: Colors.white24, size: 24),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, color: TxaTheme.accent, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              TxaLanguage.t('watching'),
                              style: const TextStyle(
                                color: TxaTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (epDisplay.isNotEmpty) ...[
                              const Text(' • ', style: TextStyle(color: Colors.white38)),
                              Expanded(
                                child: Text(
                                  epDisplay,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          movieName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(TxaTheme.accent),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => MovieDetailScreen(slug: slug),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TxaTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      TxaLanguage.t('watch_now'),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryQuickFilters() {
    final categories = [
      {'key': 'ALL', 'label': TxaLanguage.t('see_all')},
      {'key': 'TXA_NEW1', 'label': TxaLanguage.t('TXA_NEW1')},
      {'key': 'TXA_HOT1', 'label': TxaLanguage.t('TXA_HOT1')},
      {'key': 'TXA_PB1', 'label': TxaLanguage.t('TXA_PB1')},
      {'key': 'TXA_PL1', 'label': TxaLanguage.t('TXA_PL1')},
      {'key': 'TXA_HH1', 'label': TxaLanguage.t('TXA_HH1')},
      {'key': 'TXA_CR1', 'label': TxaLanguage.t('TXA_CR1')},
      {'key': 'TXA_TV1', 'label': TxaLanguage.t('TXA_TV1')},
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategoryKey == cat['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(
                cat['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              selectedColor: TxaTheme.accent,
              backgroundColor: TxaTheme.secondaryBg.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? TxaTheme.accent : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategoryKey = cat['key']!;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCountryFilters() {
    final countries = [
      {'key': null, 'label': TxaLanguage.t('country_all')},
      {'key': 'trung quốc', 'label': TxaLanguage.t('country_china')},
      {'key': 'hàn quốc', 'label': TxaLanguage.t('country_korea')},
      {'key': 'việt nam', 'label': TxaLanguage.t('country_vietnam')},
      {'key': 'âu mỹ', 'label': TxaLanguage.t('country_us_uk')},
      {'key': 'nhật bản', 'label': TxaLanguage.t('country_japan')},
      {'key': 'thái lan', 'label': TxaLanguage.t('country_thailand')},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: countries.length,
        itemBuilder: (context, index) {
          final country = countries[index];
          final isSelected = _selectedCountryKey == country['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCountryKey = country['key'];
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    country['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovieShelf(String title, List<dynamic> movies, String typeKey) {
    if (_selectedCategoryKey != 'ALL' && _selectedCategoryKey != typeKey) {
      return const SizedBox.shrink();
    }
    final isHotShelf = typeKey == 'TXA_HOT1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 20.0, bottom: 12.0, right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryKey = typeKey;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      TxaLanguage.t('see_all'),
                      style: const TextStyle(
                        color: TxaTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: TxaTheme.accent,
                      size: 11,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return _buildMovieCard(movie, rankIndex: isHotShelf ? index : null);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(dynamic movie, {int? rankIndex}) {
    final posterUrl = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final name = movie['name'] ?? '';
    final slug = movie['slug'] ?? '';
    final episode = movie['episode_current'] ?? 'Full';
    final hasRank = rankIndex != null && rankIndex < 10;
    final quality = movie['quality'] ?? 'FHD';
    final year = movie['year']?.toString() ?? '2026';
    final lang = movie['lang'] ?? 'Vietsub';
    
    // Rating score
    dynamic tmdbVote = movie['tmdb']?['vote_average'];
    dynamic imdbVote = movie['imdb']?['vote_average'];
    String imdbScore = (tmdbVote ?? imdbVote ?? '').toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => MovieDetailScreen(slug: slug),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie Poster inside Liquid Glass card
            TxaTheme.liquidGlassPill(
              radius: 16,
              child: SizedBox(
                height: 160,
                width: 120,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(color: TxaTheme.cardBg),
                        ),
                      ),
                    ),
                    // Combined Badges Row (Top Left & Top Right)
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                episode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: TxaTheme.accent.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              quality,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasRank)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: rankIndex == 0
                                ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                                : (rankIndex == 1
                                    ? const LinearGradient(colors: [Color(0xFFE6E6E6), Color(0xFF9E9E9E)])
                                    : (rankIndex == 2
                                        ? const LinearGradient(colors: [Color(0xFFE69A58), Color(0xFF8B4513)])
                                        : TxaTheme.brandGradient)),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '#${rankIndex + 1}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    // Bottom bar gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.95),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Year Tag (Bottom Left)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          year,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Language Tag (Bottom Right)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          lang,
                          style: const TextStyle(
                            color: TxaTheme.textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // IMDb rating (Bottom Center)
                    if (imdbScore.isNotEmpty && imdbScore != '0')
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.black, size: 7),
                                const SizedBox(width: 1.5),
                                Text(
                                  imdbScore,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // ❤️ Favorite button - top right corner
                    Positioned(
                      top: 32,
                      right: 4,
                      child: ValueListenableBuilder<Set<String>>(
                        valueListenable: TxaFavoriteManager().favorites,
                        builder: (context, favSet, _) {
                          final isFav = favSet.contains(slug);
                          return GestureDetector(
                            onTap: () async {
                              final auth = Provider.of<TxaAuthService>(context, listen: false);
                              if (!auth.isLoggedIn) {
                                TxaToast.show(context, TxaLanguage.t('login_required_favorites'));
                                return;
                              }
                              // Optimistic update
                              TxaFavoriteManager().setFavorite(slug, !isFav);
                              final res = await TxaApi().toggleFavorite(slug);
                              if (res != null) {
                                final confirmed = res['is_favorite'] == true;
                                TxaFavoriteManager().setFavorite(slug, confirmed);
                                if (context.mounted) {
                                  TxaToast.show(
                                    context,
                                    confirmed
                                        ? TxaLanguage.t('favorite_added')
                                        : TxaLanguage.t('favorite_removed'),
                                  );
                                }
                              } else {
                                // Revert
                                TxaFavoriteManager().setFavorite(slug, isFav);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFav ? Colors.redAccent : Colors.white70,
                                size: 14,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridMovieCard(dynamic movie) {
    final name = movie['name'] ?? '';
    final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final slug = movie['slug'] ?? '';
    final quality = movie['quality'] ?? 'FHD';
    final episode = movie['episode_current'] ?? 'Full';
    final year = movie['year']?.toString() ?? '2026';
    final lang = movie['lang'] ?? 'Vietsub';
    
    dynamic tmdbVote = movie['tmdb']?['vote_average'];
    dynamic imdbVote = movie['imdb']?['vote_average'];
    String imdbScore = (tmdbVote ?? imdbVote ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => MovieDetailScreen(slug: slug)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TxaTheme.liquidGlassPill(
              radius: 16,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(color: TxaTheme.cardBg),
                    errorWidget: (ctx, url, err) => Container(color: TxaTheme.cardBg),
                  ),
                  // Episode Tag
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        episode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Quality Tag
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        quality,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Bottom bar gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.95),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Year Tag (Bottom Left)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        year,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Language Tag (Bottom Right)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        lang,
                        style: const TextStyle(
                          color: TxaTheme.textSecondary,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // IMDb rating
                  if (imdbScore.isNotEmpty && imdbScore != '0')
                    Positioned(
                      bottom: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.black, size: 7),
                              const SizedBox(width: 1.5),
                              Text(
                                imdbScore,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Favorite button
                  Positioned(
                    top: 30,
                    right: 4,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: TxaFavoriteManager().favorites,
                      builder: (context, favSet, _) {
                        final isFav = favSet.contains(slug);
                        return GestureDetector(
                          onTap: () async {
                            final auth = Provider.of<TxaAuthService>(context, listen: false);
                            if (!auth.isLoggedIn) {
                              TxaToast.show(context, TxaLanguage.t('login_required_favorites'));
                              return;
                            }
                            TxaFavoriteManager().setFavorite(slug, !isFav);
                            final res = await TxaApi().toggleFavorite(slug);
                            if (res != null) {
                              final confirmed = res['is_favorite'] == true;
                              TxaFavoriteManager().setFavorite(slug, confirmed);
                              if (context.mounted) {
                                TxaToast.show(
                                  context,
                                  confirmed
                                      ? TxaLanguage.t('favorite_added')
                                      : TxaLanguage.t('favorite_removed'),
                                );
                              }
                            } else {
                              TxaFavoriteManager().setFavorite(slug, isFav);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? Colors.redAccent : Colors.white70,
                              size: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            movie['origin_name'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}
