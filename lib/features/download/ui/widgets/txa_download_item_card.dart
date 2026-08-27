import 'package:flutter/material.dart';
import '../../models/txa_download_status.dart';
import '../../models/txa_download_task.dart';
import '../../services/txa_download_service.dart';

class TxaDownloadItemCard extends StatelessWidget {
  final TxaDownloadTask task;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const TxaDownloadItemCard({
    Key? key,
    required this.task,
    this.onRetry,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isFailed = task.isFailed;
    final isCompleted = task.isCompleted;
    final isDownloading = task.isDownloading;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFailed
              ? const Color(0xFFEF4444).withOpacity(0.4)
              : isCompleted
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : Colors.white.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossCrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Trạng thái Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isFailed
                      ? const Color(0xFFEF4444).withOpacity(0.15)
                      : isCompleted
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : const Color(0xFFA78BFA).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isFailed
                        ? Icons.error_outline_rounded
                        : isCompleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.arrow_downward_rounded,
                    color: isFailed
                        ? const Color(0xFFEF4444)
                        : isCompleted
                            ? const Color(0xFF10B981)
                            : const Color(0xFFA78BFA),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tên tập phim & Tên phim
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossCrossAxisAlignment.start,
                  children: [
                    Text(
                      task.episodeName.isNotEmpty ? task.episodeName : 'Tập Phim',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.filmTitle,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action buttons (Play, Retry, Cancel)
              if (isFailed)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFFA78BFA), size: 22),
                  onPressed: onRetry,
                  tooltip: 'Thử lại',
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                onPressed: onCancel,
                tooltip: 'Xóa',
              ),
            ],
          ),

          // Lỗi hiển thị đẹp theo StatusCode (Không raw DioException)
          if (isFailed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Mã ${task.statusCode}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.localizedStatusMessage,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Thanh tiến trình khi đang tải
          if (isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
