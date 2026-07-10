import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../services/txa_auth_service.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'txa_movie_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final TxaApi _api = TxaApi();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _isAuthError = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final auth = Provider.of<TxaAuthService>(context, listen: false);
    if (!auth.isLoggedIn) {
      setState(() {
        _isAuthError = true;
        _isLoading = false;
        _notifications.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isAuthError = false;
    });

    try {
      final response = await _api.getNotifications();
      if (mounted) {
        if (response != null && response['success'] == true) {
          setState(() {
            _notifications = response['data'] as List? ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    final success = await _api.markNotificationRead(id);
    if (success && mounted) {
      // Update local state
      setState(() {
        for (var n in _notifications) {
          if (n['id'] == id) {
            n['is_read'] = true;
          }
        }
      });
      TxaToast.show(context, TxaLanguage.t('toast_marked_read'));
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await _api.markAllNotificationsRead();
    if (success && mounted) {
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      TxaToast.show(context, TxaLanguage.t('toast_marked_all_read'));
    }
  }

  Future<void> _clearAll() async {
    final success = await _api.clearNotifications();
    if (success && mounted) {
      setState(() {
        _notifications.clear();
      });
      TxaToast.show(context, TxaLanguage.t('toast_cleared_all'));
    }
  }

  void _openMovie(String slug, String id) async {
    // Mark as read on backend & update local list
    await _api.markNotificationRead(id);
    if (mounted) {
      setState(() {
        for (var n in _notifications) {
          if (n['id'] == id) {
            n['is_read'] = true;
          }
        }
      });
    }

    // Open detail screen
    if (mounted && slug.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => MovieDetailScreen(slug: slug),
        ),
      );
    }
  }

  String _formatRelativeTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) {
        return 'Vừa xong';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} phút trước';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} giờ trước';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      }
    } catch (_) {
      return '';
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
          TxaLanguage.t('notifications'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading && !_isAuthError && _notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: TxaTheme.accent, size: 22),
              tooltip: TxaLanguage.t('mark_all_read'),
              onPressed: _markAllAsRead,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22),
              tooltip: TxaLanguage.t('clear_all'),
              onPressed: _clearAll,
            ),
          ]
        ],
      ),
      body: Stack(
        children: [
          // Background ambient gradient glow
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TxaTheme.accent.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: TxaTheme.accent.withValues(alpha: 0.08),
                    blurRadius: 80,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),

          // Main view
          RefreshIndicator(
            color: TxaTheme.accent,
            backgroundColor: TxaTheme.cardBg,
            onRefresh: _fetchNotifications,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: TxaTheme.accent),
      );
    }

    if (_isAuthError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: TxaTheme.liquidGlassPill(
            radius: 24,
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TxaTheme.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded, color: TxaTheme.accent, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  TxaLanguage.t('login_prompt_title'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  TxaLanguage.t('login_prompt_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, 'go_to_profile');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TxaTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(TxaLanguage.t('login_now'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              children: [
                const Icon(Icons.notifications_none_rounded, color: TxaTheme.textMuted, size: 64),
                const SizedBox(height: 16),
                Text(
                  TxaLanguage.t('no_notifications'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  TxaLanguage.t('no_notifications_desc'),
                  style: const TextStyle(color: TxaTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final item = _notifications[index];
        final id = item['id']?.toString() ?? '';
        final title = item['title']?.toString() ?? '';
        final body = item['body']?.toString() ?? '';
        final imageUrl = item['image_url']?.toString() ?? '';
        final movieSlug = item['movie_slug']?.toString() ?? '';
        final isRead = item['is_read'] == true;
        final timeStr = _formatRelativeTime(item['created_at'] ?? '');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: TxaTheme.liquidGlassPill(
            radius: 18,
            borderGlowColor: isRead ? null : TxaTheme.accent.withValues(alpha: 0.3),
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
                    onTap: () {
                      if (movieSlug.isNotEmpty) {
                        _openMovie(movieSlug, id);
                      } else {
                        _markAsRead(id);
                      }
                    },
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(color: TxaTheme.cardBg),
                                errorWidget: (c, u, e) => Container(
                                  color: TxaTheme.cardBg,
                                  child: const Icon(Icons.movie_filter_rounded, color: TxaTheme.accent, size: 20),
                                ),
                              )
                            : Container(
                                color: TxaTheme.accent.withValues(alpha: 0.1),
                                child: const Icon(Icons.notifications_active_rounded, color: TxaTheme.accent, size: 20),
                              ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: TxaTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timeStr,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isRead)
                          TextButton.icon(
                            onPressed: () => _markAsRead(id),
                            icon: const Icon(Icons.done_all_rounded, size: 14),
                            label: Text(TxaLanguage.t('mark_read'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: TxaTheme.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (movieSlug.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openMovie(movieSlug, id),
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 14),
                            label: Text(TxaLanguage.t('open_movie'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TxaTheme.accent.withValues(alpha: 0.15),
                              foregroundColor: TxaTheme.accent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: TxaTheme.accent.withValues(alpha: 0.25)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
