import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/txa_local_film.dart';
import '../services/txa_download_manager.dart';
import '../services/txa_storage_estimator.dart';
import 'downloaded_episodes_screen.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../services/txa_language.dart';
import '../../../../services/txa_offline_history_service.dart';

class DownloadedFilmsScreen extends StatefulWidget {
  const DownloadedFilmsScreen({super.key});

  @override
  State<DownloadedFilmsScreen> createState() => _DownloadedFilmsScreenState();
}

class _DownloadedFilmsScreenState extends State<DownloadedFilmsScreen> {
  @override
  void initState() {
    super.initState();
    // Đồng bộ toàn bộ lịch sử xem ngoại tuyến lên CSDL máy chủ khi mở thư viện tải
    TxaOfflineHistoryService.syncPendingHistory();
  }

  Widget _buildSystemStorageSection(int totalAppBytes) {
    return FutureBuilder<TxaStorageInfo>(
      future: TxaStorageEstimator.getStorageInfo(totalAppBytes),
      builder: (context, snap) {
        final info = snap.data ??
            TxaStorageInfo(
              totalBytes: 128 * 1024 * 1024 * 1024,
              usedBytes: 45 * 1024 * 1024 * 1024 + totalAppBytes,
              freeBytes: 83 * 1024 * 1024 * 1024 - totalAppBytes,
              appBytes: totalAppBytes,
            );

        final usedStr = TxaFormat.formatFileSize(info.usedBytes);
        final totalStr = TxaFormat.formatFileSize(info.totalBytes);
        final appStr = TxaFormat.formatFileSize(info.appBytes);
        final freeStr = TxaFormat.formatFileSize(info.freeBytes);
        final otherUsedBytes = (info.usedBytes - info.appBytes).clamp(0, info.totalBytes);
        final otherStr = TxaFormat.formatFileSize(otherUsedBytes);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: TxaTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dung lượng đã dùng thực tế / tổng dung lượng hệ thống
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${TxaLanguage.t('storage_used')}: $usedStr / $totalStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(info.usedRatio * 100).toInt()}%',
                    style: const TextStyle(
                      color: TxaTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Thanh div progress ngay dưới
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Container(color: Colors.white10),
                      FractionallySizedBox(
                        widthFactor: info.usedRatio,
                        child: Container(color: Colors.white30),
                      ),
                      FractionallySizedBox(
                        widthFactor: info.appRatio.clamp(0.005, 1.0),
                        child: Container(color: TxaTheme.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Chú giải dưới: Dung lượng dùng thực tế của app nằm ở đây thay vì mục riêng ở trên
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: TxaTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'DongMePhim: $appStr',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${TxaLanguage.t('storage_other')}: $otherStr',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${TxaLanguage.t('storage_free')}: $freeStr',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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

          final totalAllBytes = films.fold<int>(0, (sum, f) => sum + f.totalBytes);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: films.length + 1,
            itemBuilder: (ctx, idx) {
              if (idx == 0) {
                // Storage progress bar với chú giải dung lượng thực tế của app ở dưới
                return _buildSystemStorageSection(totalAllBytes);
              }

              final film = films[idx - 1];
              final totalSizeStr = TxaFormat.formatFileSize(film.totalBytes);
              final isAllCompleted = film.totalCount > 0 && film.completedCount == film.totalCount;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TxaTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DownloadedEpisodesScreen(film: film),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: film.filmPoster.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: film.filmPoster,
                                    width: 58,
                                    height: 82,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.white10),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 58,
                                      height: 82,
                                      color: Colors.white10,
                                      child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                    ),
                                  )
                                : Container(
                                    width: 58,
                                    height: 82,
                                    color: Colors.white10,
                                    child: const Icon(Icons.movie_rounded, color: Colors.white38),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  film.filmTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isAllCompleted
                                            ? Colors.greenAccent.withValues(alpha: 0.15)
                                            : TxaTheme.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${film.completedCount}/${film.totalCount} ${TxaLanguage.t('all_episodes')}',
                                        style: TextStyle(
                                          color: isAllCompleted ? Colors.greenAccent : TxaTheme.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        totalSizeStr,
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
