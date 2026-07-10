import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/txa_api.dart';
import '../../services/txa_language.dart';
import '../widgets/tv_focusable_card.dart';
import '../navigation/tv_focus_system.dart';
import 'tv_movie_detail_screen.dart';

class TvWatchHistoryScreen extends StatefulWidget {
  const TvWatchHistoryScreen({super.key});

  @override
  State<TvWatchHistoryScreen> createState() => _TvWatchHistoryScreenState();
}

class _TvWatchHistoryScreenState extends State<TvWatchHistoryScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final res = await TxaApi().getWatchHistory();
      if (!mounted) return;
      setState(() {
        _items = res;
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
          focusNode: TvFocusSystem.getNode('tv_history_back'),
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          TxaLanguage.t('tv_shelf_history'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _items.isEmpty && !_loading
          ? Center(
              child: Text(
                TxaLanguage.t('no_favorites_yet'),
                style: const TextStyle(color: Colors.white30, fontSize: 14),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final name = item['movie_name'] ?? '';
                final epName = item['episode_name'] ?? '';
                final thumbUrl = item['movie_thumb'] ?? '';
                final double currentTime = (item['current_time'] as num? ?? 0.0).toDouble();
                final double duration = (item['duration'] as num? ?? 1.0).toDouble();
                final progressPercent = duration > 0 ? (currentTime / duration).clamp(0.0, 1.0) : 0.0;
                final node = TvFocusSystem.getNode('tv_history_$index');

                return TvFocusableCard(
                  focusNode: node,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => TvMovieDetailScreen(slug: item['movie_slug'] ?? ''),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: Colors.white12),
                          errorWidget: (c, u, e) => Container(color: Colors.white10),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.black87, Colors.transparent],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(epName, style: const TextStyle(color: Color(0xFF737DFD), fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progressPercent,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF737DFD),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
