import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/txa_api.dart';
import '../../services/txa_favorite_manager.dart';
import '../../services/txa_language.dart';
import '../widgets/tv_focusable_card.dart';
import '../navigation/tv_focus_system.dart';
import 'tv_movie_detail_screen.dart';

class TvFavoritesScreen extends StatefulWidget {
  const TvFavoritesScreen({super.key});

  @override
  State<TvFavoritesScreen> createState() => _TvFavoritesScreenState();
}

class _TvFavoritesScreenState extends State<TvFavoritesScreen> {
  final List<dynamic> _items = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    TxaFavoriteManager().favorites.addListener(_onFavoritesChanged);
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
    super.dispose();
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final res = await TxaApi().getFavorites(page: _page, limit: 30);
      if (!mounted) return;
      final data = res?['data'] as List<dynamic>? ?? [];
      setState(() {
        if (loadMore) {
          _items.addAll(data);
        } else {
          _items.clear();
          _items.addAll(data);
        }
        _hasMore = data.length >= 30;
        _page++;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0D14),
        elevation: 0,
        leading: TvFocusableCard(
          focusNode: TvFocusSystem.getNode('tv_fav_back'),
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          TxaLanguage.t('tv_shelf_favorites'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _items.isEmpty && !_loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border_rounded, color: Colors.white24, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    TxaLanguage.t('tv_no_favorites'),
                    style: const TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    _scrollPositionAtBottom(notification.metrics) &&
                    !_loading &&
                    _hasMore) {
                  _loadData(loadMore: true);
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.65,
                ),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: Color(0xFF737DFD)),
                      ),
                    );
                  }
                  final movie = _items[index];
                  final poster = movie['poster_url'] ?? movie['thumb_url'] ?? '';
                  final name = movie['name'] ?? '';
                  final node = TvFocusSystem.getNode('tv_fav_$index');

                  return TvFocusableCard(
                    focusNode: node,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => TvMovieDetailScreen(slug: movie['slug'] ?? ''),
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
                            placeholder: (c, u) => Container(color: Colors.white12),
                            errorWidget: (c, u, e) => Container(color: Colors.white10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  bool _scrollPositionAtBottom(ScrollMetrics metrics) {
    return metrics.pixels >= metrics.maxScrollExtent - 200;
  }
}
