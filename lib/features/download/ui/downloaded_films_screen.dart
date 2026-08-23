import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/txa_local_film.dart';
import '../services/txa_download_manager.dart';
import 'downloaded_episodes_screen.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../services/txa_language.dart';

class DownloadedFilmsScreen extends StatelessWidget {
  const DownloadedFilmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TxaDownloadManager>(context);

    return Scaffold(
      backgroundColor: TxaTheme.primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          TxaLanguage.t('downloaded_movies'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<TxaLocalFilm>>(
        future: manager.getAllLocalFilms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: TxaTheme.accent));
          }

          final films = snapshot.data ?? [];
          if (films.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_for_offline_outlined, color: Colors.white24, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('offline_no_downloads_title'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      TxaLanguage.t('no_history_msg'),
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: films.length,
            itemBuilder: (ctx, idx) {
              final film = films[idx];
              final totalSizeStr = TxaFormat.formatFileSize(film.totalBytes);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TxaTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: film.filmPoster.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: film.filmPoster,
                            width: 54,
                            height: 75,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.white10),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.white10,
                              child: const Icon(Icons.movie_rounded, color: Colors.white38),
                            ),
                          )
                        : Container(
                            width: 54,
                            height: 75,
                            color: Colors.white10,
                            child: const Icon(Icons.movie_rounded, color: Colors.white38),
                          ),
                  ),
                  title: Text(
                    film.filmTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: TxaTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${film.completedCount}/${film.totalCount} ${TxaLanguage.t('episode_label', replace: {'n': ''}).trim()}',
                            style: const TextStyle(color: TxaTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          totalSizeStr,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DownloadedEpisodesScreen(film: film),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
