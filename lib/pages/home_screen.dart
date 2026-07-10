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
import 'txa_category_list_screen.dart';
import 'txa_search_tab.dart';
import 'txa_profile_screen.dart';
import 'txa_schedule_tab.dart';
import '../widgets/txa_coachmark.dart';

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
          final newMovies = getList(data['TXA_NEW1']);
          final hotMovies = getList(data['TXA_HOT1']);
          final animeList = getList(data['TXA_HH1']);
          final seriesList = getList(data['TXA_PB1']);
          final singleList = getList(data['TXA_PL1']);
          final theaterList = getList(data['TXA_CR1']);
          final tvShowsList = getList(data['TXA_TV1']);

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
                    bottom: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
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
                                    backgroundImage: (auth.isLoggedIn && auth.user?['avatar_url'] != null && auth.user!['avatar_url'].toString().isNotEmpty)
                                        ? NetworkImage(auth.user!['avatar_url'].toString())
                                        : null,
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

              // Hero spotlight banner
              if (sliderList.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildHeroSpotlight(sliderList.first),
                ),

              // Shelves List
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
                    if (theaterList.isNotEmpty)
                      _buildMovieShelf(TxaLanguage.t('TXA_CR1'), theaterList, 'TXA_CR1'),
                    if (tvShowsList.isNotEmpty)
                      _buildMovieShelf(TxaLanguage.t('TXA_TV1'), tvShowsList, 'TXA_TV1'),
                  ]),
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

  Widget _buildMovieShelf(String title, List<dynamic> movies, String typeKey) {
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => CategoryListScreen(
                        title: title,
                        type: typeKey,
                      ),
                    ),
                  );
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
              return _buildMovieCard(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(dynamic movie) {
    final posterUrl = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final name = movie['name'] ?? '';
    final slug = movie['slug'] ?? '';
    final episode = movie['episode_current'] ?? 'Full';
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
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
}
