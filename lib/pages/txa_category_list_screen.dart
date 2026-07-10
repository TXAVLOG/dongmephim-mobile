import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../services/txa_favorite_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'txa_movie_detail_screen.dart';

class CategoryListScreen extends StatefulWidget {
  final String title;
  final String? slug;
  final String? type;

  const CategoryListScreen({
    super.key,
    required this.title,
    this.slug,
    this.type,
  });

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final List<dynamic> _items = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _loadData(loadMore: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (loadMore) {
      _page++;
    } else {
      _page = 1;
      _error = null;
      _items.clear();
    }

    setState(() => _loading = true);

    try {
      Map<String, dynamic>? res;
      if (widget.slug != null) {
        res = await TxaApi().getCategory(widget.slug!, page: _page);
      } else if (widget.type != null) {
        res = await TxaApi().getType(widget.type!, page: _page);
      }

      if (res != null) {
        // Safe mapping
        final data = res;
        final List<dynamic> list = data['movies']?['data'] as List? ??
            data['data'] as List? ??
            data['items'] as List? ??
            [];

        setState(() {
          _items.addAll(list);
          _loading = false;
          _hasMore = list.length >= 10; // Check if there's more data
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load category data';
        });
      }
    } catch (e) {
      if (mounted && !loadMore) {
        TxaToast.show(
          context,
          TxaLanguage.t('error_loading_data'),
          isError: true,
        );
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _items.isEmpty && _loading
          ? const Center(
              child: CircularProgressIndicator(color: TxaTheme.accent),
            )
          : _error != null && _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        TxaLanguage.t('error_loading_data'),
                        style: const TextStyle(color: TxaTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _loadData(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(TxaLanguage.t('retry')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TxaTheme.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.55,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final movie = _items[index];
                          return _MovieGridItem(
                            key: ValueKey('grid_${movie['id']}_$index'),
                            movie: movie,
                          );
                        }, childCount: _items.length),
                      ),
                    ),
                    if (_loading && _items.isNotEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: TxaTheme.accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _MovieGridItem extends StatelessWidget {
  final dynamic movie;
  const _MovieGridItem({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final name = movie['name'] ?? '';
    final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final slug = movie['slug'] ?? '';
    final quality = movie['quality'] ?? 'FHD';
    final episode = movie['episode_current'] ?? 'Full';
    final year = movie['year']?.toString() ?? '2026';
    final lang = movie['lang'] ?? 'Vietsub';
    
    // Rating calculation
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
                  // ❤️ Favorite button overlay
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
