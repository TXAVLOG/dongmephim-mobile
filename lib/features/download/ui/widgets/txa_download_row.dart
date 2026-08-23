import 'package:flutter/material.dart';
import '../../models/txa_download_status.dart';
import '../../models/txa_download_task.dart';
import 'txa_progress_ring.dart';
import '../../../../theme/txa_theme.dart';
import '../../../../utils/txa_format.dart';
import '../../../../services/txa_language.dart';

class TxaDownloadRow extends StatelessWidget {
  final String episodeName;
  final String? estimatedSizeStr;
  final bool isSelected;
  final TxaDownloadTask? task;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const TxaDownloadRow({
    super.key,
    required this.episodeName,
    this.estimatedSizeStr,
    this.isSelected = false,
    this.task,
    this.onSelectedChanged,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = task?.status;
    final isCompleted = status == TxaDownloadStatus.completed;
    final isDownloading = status == TxaDownloadStatus.downloading;
    final isMerging = status == TxaDownloadStatus.merging;
    final isPaused = status == TxaDownloadStatus.paused;
    final isQueued = status == TxaDownloadStatus.queued;
    final isFailed = status == TxaDownloadStatus.failed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? TxaTheme.accent.withValues(alpha: 0.12) : TxaTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? TxaTheme.accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Checkbox or Status Icon
          if (isCompleted)
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 24)
          else if (isDownloading || isMerging)
            TxaProgressRing(
              progress: task?.progress ?? 0.0,
              size: 26,
              strokeWidth: 2.5,
              child: isMerging
                  ? const Icon(Icons.sync_rounded, color: TxaTheme.accent, size: 14)
                  : Text(
                      '${((task?.progress ?? 0) * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
            )
          else if (isQueued)
            const Icon(Icons.schedule_rounded, color: Colors.amberAccent, size: 22)
          else if (isPaused)
            const Icon(Icons.pause_circle_filled_rounded, color: Colors.white54, size: 22)
          else if (isFailed)
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 22)
          else
            Checkbox(
              value: isSelected,
              onChanged: onSelectedChanged,
              activeColor: TxaTheme.accent,
              checkColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),

          const SizedBox(width: 10),

          // Episode Info & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TxaFormat.formatEpisodeName(episodeName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                if (isDownloading) ...[
                  Text(
                    '🚀 ${TxaFormat.formatSpeed(task?.speed ?? 0)['display']} • ⏳ ETA: ${TxaFormat.formatDuration(task?.eta ?? 0)}',
                    style: const TextStyle(color: TxaTheme.accent, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${TxaFormat.formatFileSize(task?.downloadedBytes ?? 0)} / ${TxaFormat.formatFileSize(task?.totalBytes ?? 0)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ] else if (isMerging)
                  Text(
                    TxaLanguage.t('download_status_merging'),
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                  )
                else if (isQueued)
                  Text(
                    TxaLanguage.t('pending'),
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                  )
                else if (isPaused)
                  Text(
                    TxaLanguage.t('paused'),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  )
                else if (isFailed)
                  Text(
                    task?.errorMessage ?? TxaLanguage.t('error'),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  )
                else if (isCompleted)
                  Text(
                    '${TxaLanguage.t('download_completed')} • ${TxaFormat.formatFileSize(task?.downloadedBytes ?? 0)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                  )
                else if (estimatedSizeStr != null)
                  Text(
                    '~$estimatedSizeStr',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Action buttons (Pause/Resume/Cancel)
          if (isDownloading)
            IconButton(
              icon: const Icon(Icons.pause_rounded, color: Colors.white70, size: 20),
              onPressed: onPause,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            )
          else if (isPaused || isFailed)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: TxaTheme.accent, size: 22),
              onPressed: onResume,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),

          if (isDownloading || isPaused || isQueued || isFailed)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
              onPressed: onCancel,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
