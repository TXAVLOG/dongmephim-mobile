import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../services/txa_api.dart';
import '../../services/txa_auth_service.dart';
import '../../services/txa_favorite_manager.dart';
import '../../services/txa_language.dart';
import '../../utils/txa_toast.dart';
import '../widgets/tv_focusable_card.dart';
import '../navigation/tv_focus_system.dart';
import '../navigation/tv_key_handler.dart';
import '../services/tv_cache_service.dart';
import 'tv_player_screen.dart';

class TvMovieDetailScreen extends StatefulWidget {
  final String slug;

  const TvMovieDetailScreen({
    super.key,
    required this.slug,
  });

  @override
  State<TvMovieDetailScreen> createState() => _TvMovieDetailScreenState();
}

class _TvMovieDetailScreenState extends State<TvMovieDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _movie;
  List<dynamic> _episodes = [];

  @override
  void initState() {
    super.initState();
    _setupFocusNodes();
    _loadMovieDetail();
  }

  void _setupFocusNodes() {
    final backNode = TvFocusSystem.getNode('detail_back');
    backNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (TvKeyHandler.isDpadRight(event) || TvKeyHandler.isDpadDown(event)) {
          TvFocusSystem.getNode('detail_favorite').requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    final favoriteNode = TvFocusSystem.getNode('detail_favorite');
    favoriteNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (TvKeyHandler.isDpadLeft(event) || TvKeyHandler.isDpadUp(event)) {
          TvFocusSystem.getNode('detail_back').requestFocus();
          return KeyEventResult.handled;
        } else if (TvKeyHandler.isDpadDown(event)) {
          if (_movie?['seasons'] != null && (_movie!['seasons'] as List).isNotEmpty) {
            TvFocusSystem.getNode('detail_season_0').requestFocus();
          } else if (_episodes.isNotEmpty) {
            TvFocusSystem.getNode('detail_episode_0').requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    final seasonNode = TvFocusSystem.getNode('detail_season_0');
    seasonNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (TvKeyHandler.isDpadUp(event)) {
          TvFocusSystem.getNode('detail_favorite').requestFocus();
          return KeyEventResult.handled;
        } else if (TvKeyHandler.isDpadDown(event)) {
          if (_episodes.isNotEmpty) {
            TvFocusSystem.getNode('detail_episode_0').requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    final firstEpisodeNode = TvFocusSystem.getNode('detail_episode_0');
    firstEpisodeNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (TvKeyHandler.isDpadUp(event)) {
          if (_movie?['seasons'] != null && (_movie!['seasons'] as List).isNotEmpty) {
            TvFocusSystem.getNode('detail_season_0').requestFocus();
          } else {
            TvFocusSystem.getNode('detail_favorite').requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  void _requestInitialFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TvFocusSystem.getNode('detail_favorite').requestFocus();
      }
    });
  }

  @override
  void dispose() {
    TvFocusSystem.disposeScreen('detail_');
    super.dispose();
  }

  Future<void> _loadMovieDetail() async {
    // 1. Try reading cache first
    try {
      final cached = await TvCacheService().read('movie_${widget.slug}');
      if (cached != null && cached['movie'] != null) {
        final isFav = cached['movie']['is_favorite'] == true;
        TxaFavoriteManager().setFavorite(widget.slug, isFav);
        setState(() {
          _movie = cached['movie'] as Map<String, dynamic>;
          _episodes = _extractEpisodes(cached);
          _isLoading = false;
        });
        _setupFocusNodes();
        _requestInitialFocus();
      }
    } catch (_) {}

    // 2. Fetch from API
    try {
      final res = await TxaApi().getMovie(widget.slug);
      if (res != null && res['movie'] != null && mounted) {
        await TvCacheService().write('movie_${widget.slug}', res);
        final isFav = res['movie']['is_favorite'] == true;
        TxaFavoriteManager().setFavorite(widget.slug, isFav);
        setState(() {
          _movie = res['movie'] as Map<String, dynamic>;
          _episodes = _extractEpisodes(res);
          _isLoading = false;
        });
        _setupFocusNodes();
        _requestInitialFocus();
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          TxaToast.show(context, TxaLanguage.t('tv_movie_not_found'), isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        TxaToast.show(context, TxaLanguage.t('tv_server_error'), isError: true);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      TxaToast.show(context, TxaLanguage.t('login_required_favorites'), isError: true);
      return;
    }
    final current = TxaFavoriteManager().isFavorite(widget.slug);
    // Optimistic update
    TxaFavoriteManager().setFavorite(widget.slug, !current);
    final res = await TxaApi().toggleFavorite(widget.slug);
    if (res != null) {
      final confirmed = res['is_favorite'] == true;
      TxaFavoriteManager().setFavorite(widget.slug, confirmed);
      if (mounted) {
        TxaToast.show(
          context,
          confirmed
              ? TxaLanguage.t('favorite_added')
              : TxaLanguage.t('favorite_removed'),
        );
      }
    } else {
      // Revert on error
      TxaFavoriteManager().setFavorite(widget.slug, current);
    }
  }

  /// Extract episode list from API response.
  /// The API returns servers[].server_data[] containing episodes.
  List<dynamic> _extractEpisodes(Map<String, dynamic> data) {
    // Try servers[0].server_data first (standard API response)
    final servers = data['servers'] as List<dynamic>? ?? [];
    if (servers.isNotEmpty) {
      final firstServer = servers[0] as Map<String, dynamic>? ?? {};
      final serverData = firstServer['server_data'] as List<dynamic>? ?? [];
      if (serverData.isNotEmpty) return serverData;
    }
    // Fallback to episodes key (legacy/cache)
    return data['episodes'] as List<dynamic>? ?? [];
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

    final movieInfo = _movie!;
    final name = movieInfo['name'] ?? '';
    final originName = movieInfo['origin_name'] ?? '';
    final thumb = movieInfo['thumb_url'] ?? movieInfo['poster_url'] ?? '';
    final poster = movieInfo['poster_url'] ?? '';
    final description = movieInfo['content'] ?? movieInfo['description'] ?? TxaLanguage.t('tv_no_description');
    final year = movieInfo['year'] ?? movieInfo['publish_year'] ?? '2026';
    final rawCategories = movieInfo['categories'] as List<dynamic>? ?? [];
    final category = rawCategories.isNotEmpty
        ? rawCategories.map((c) => c is Map ? (c['name'] ?? '') : c.toString()).join(', ')
        : (movieInfo['category'] ?? 'Phim').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: Stack(
        children: [
          // Background blurred backdrop
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF090A0F), Colors.black54],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          // Main Layout split: Left Poster, Right Info & Episodes
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Large Poster + Back Button
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        TvFocusableCard(
                          focusNode: TvFocusSystem.getNode('detail_back'),
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(TxaLanguage.t('tv_back'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Poster Image
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: poster.isNotEmpty ? poster : thumb,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white10,
                                  child: const Icon(
                                    Icons.movie_rounded,
                                    color: Colors.white30,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),

                  // Right Side: Title, Plot, Episodes Grid
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categories + Year tags
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF737DFD).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF737DFD).withValues(alpha: 0.4)),
                              ),
                              child: Text(category.toString().toUpperCase(), style: const TextStyle(color: Color(0xFF737DFD), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Text(year.toString(), style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (originName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            originName,
                            style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Description Plot
                        Text(
                          description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 20),

                        // ❤️ Favorite button
                        ValueListenableBuilder<Set<String>>(
                          valueListenable: TxaFavoriteManager().favorites,
                          builder: (context, favSet, _) {
                            final isFav = favSet.contains(widget.slug);
                            return TvFocusableCard(
                              focusNode: TvFocusSystem.getNode('detail_favorite'),
                              onTap: _toggleFavorite,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                color: isFav
                                    ? Colors.redAccent.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.08),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isFav ? Colors.redAccent : Colors.white70,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      TxaLanguage.t('tv_add_favorite'),
                                      style: TextStyle(
                                        color: isFav ? Colors.redAccent : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Seasons selector shelf
                        if (movieInfo['seasons'] != null && (movieInfo['seasons'] as List).length > 1) ...[
                          Text(
                            TxaLanguage.t('tv_select_season'),
                            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (movieInfo['seasons'] as List).length,
                              itemBuilder: (context, index) {
                                final part = movieInfo['seasons'][index];
                                final isSelected = part['slug'] == widget.slug;
                                final node = TvFocusSystem.getNode('detail_season_$index');

                                return Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: TvFocusableCard(
                                    focusNode: node,
                                    scaleOnFocus: 1.05,
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      if (!isSelected) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TvMovieDetailScreen(slug: part['slug']),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      color: isSelected
                                          ? const Color(0xFF737DFD).withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.05),
                                      alignment: Alignment.center,
                                      child: Text(
                                        part['season_name'] ?? part['name'] ?? '',
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFF737DFD) : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Episodes shelf
                        Text(
                          TxaLanguage.t('tv_episodes_list'),
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 12),

                        // Grid of episodes
                        Expanded(
                          child: _episodes.isEmpty
                              ? Center(child: Text(TxaLanguage.t('tv_no_episodes'), style: const TextStyle(color: Colors.white30)))
                              : GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemCount: _episodes.length,
                                  itemBuilder: (context, index) {
                                    final ep = _episodes[index];
                                    final epTitle = ep['name'] ?? 'Tập ${index + 1}';
                                    final node = TvFocusSystem.getNode('detail_episode_$index');

                                    return TvFocusableCard(
                                      focusNode: node,
                                      scaleOnFocus: 1.06,
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TvPlayerScreen(
                                              movieSlug: widget.slug,
                                              episodeId: ep['id']?.toString() ?? '',
                                              episodeName: epTitle,
                                              movieName: name,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        alignment: Alignment.center,
                                        child: Text(
                                          epTitle,
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // D-Pad navigation helper bar
          Positioned(
            bottom: 20,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_remote_rounded, color: Color(0xFF737DFD), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    TxaLanguage.t('tv_dpad_guide'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
