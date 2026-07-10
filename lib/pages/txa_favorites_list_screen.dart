import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/txa_api.dart';
import '../services/txa_favorite_manager.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'txa_movie_detail_screen.dart';

class TxaFavoritesListScreen extends StatefulWidget {
  const TxaFavoritesListScreen({super.key});

  @override
  State<TxaFavoritesListScreen> createState() => _TxaFavoritesListScreenState();
}

class _TxaFavoritesListScreenState extends State<TxaFavoritesListScreen> {
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
    TxaFavoriteManager().favorites.addListener(_onFavoritesChanged);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _hasMore) {
        _loadData(loadMore: true);
      }
    });
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    final favSet = TxaFavoriteManager().favorites.value;
    final filtered = _items.where((item) {
      final slug = item['slug'] as String? ?? '';
      return favSet.contains(slug);
    }).toList();
    if (filtered.length != _items.length) {
      setState(() {
        _items.clear();
        _items.addAll(filtered);
      });
    }
  }

  @override
  void dispose() {
    TxaFavoriteManager().favorites.removeListener(_onFavoritesChanged);
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
      final res = await TxaApi().getFavorites(page: _page, limit: 15);
      if (res != null) {
        final List<dynamic> list = res['data'] as List? ?? [];
        setState(() {
          _items.addAll(list);
          _loading = false;
          _hasMore = list.length >= 15;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Failed to load favorites';
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
          TxaLanguage.t('favorites_list'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(),
        color: TxaTheme.accent,
        backgroundColor: TxaTheme.cardBg,
        child: _items.isEmpty && _loading
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
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          TxaLanguage.t('no_favorites_yet'),
                          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                                return _FavoriteGridItem(
                                  key: ValueKey('fav_${movie['id']}_$index'),
                                  movie: movie,
                                  onRemove: () {
                                    setState(() {
                                      _items.removeAt(index);
                                    });
                                  },
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
      ),
    );
  }
}

class _FavoriteGridItem extends StatelessWidget {
  final dynamic movie;
  final VoidCallback onRemove;
  const _FavoriteGridItem({super.key, required this.movie, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = movie['name'] ?? '';
    final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
    final slug = movie['slug'] ?? '';
    final quality = movie['quality'] ?? 'FHD';
    final episode = movie['episode_current'] ?? 'Full';
    final year = movie['year']?.toString() ?? '';
    final lang = movie['lang'] ?? 'Vietsub';

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
                  if (year.isNotEmpty)
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
                  // ❤️ Favorite button overlay (toggles off and calls API/callback)
                  Positioned(
                    top: 30,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          TxaFavoriteManager().setFavorite(slug, false);
                          onRemove();
                          final res = await TxaApi().toggleFavorite(slug);
                          if (res != null) {
                            final confirmed = res['is_favorite'] == true;
                            TxaFavoriteManager().setFavorite(slug, confirmed);
                            if (!confirmed) {
                              if (context.mounted) {
                                TxaToast.show(context, TxaLanguage.t('favorite_removed'));
                              }
                            }
                          }
                        },
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                      ),
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
