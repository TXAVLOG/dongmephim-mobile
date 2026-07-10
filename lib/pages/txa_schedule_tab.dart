import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../theme/txa_theme.dart';
import '../services/txa_language.dart';
import '../services/txa_api.dart';
import 'txa_movie_detail_screen.dart';

class TxaScheduleTab extends StatefulWidget {
  const TxaScheduleTab({super.key});

  @override
  State<TxaScheduleTab> createState() => _TxaScheduleTabState();
}

class _TxaScheduleTabState extends State<TxaScheduleTab> {
  final TxaApi _api = TxaApi();
  List<dynamic> _scheduleDays = [];
  bool _isLoading = true;
  int _selectedDayIndex = 0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule({String? date}) async {
    setState(() {
      _isLoading = true;
    });
    
    final data = await _api.getSchedule(date: date);
    if (mounted) {
      setState(() {
        _scheduleDays = data;
        _isLoading = false;
      });
    }
  }

  String _formatDateHeader(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final today = DateTime.now();
      
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        return 'Hôm nay';
      }
      
      final weekday = DateFormat('EEEE').format(date);
      final dayStr = DateFormat('dd/MM').format(date);
      
      // Map English weekdays to Vietnamese
      final vnWeekdays = {
        'Monday': 'Thứ Hai',
        'Tuesday': 'Thứ Ba',
        'Wednesday': 'Thứ Tư',
        'Thursday': 'Thứ Năm',
        'Friday': 'Thứ Sáu',
        'Saturday': 'Thứ Bảy',
        'Sunday': 'Chủ Nhật',
      };
      
      final vnDay = vnWeekdays[weekday] ?? weekday;
      return '$vnDay ($dayStr)';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<TxaLanguage>(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Spacer
          SizedBox(height: topPadding + 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: TxaTheme.accent, size: 28),
                const SizedBox(width: 12),
                Text(
                  TxaLanguage.t('schedule'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.date_range_rounded, color: TxaTheme.accent, size: 24),
                  onPressed: () async {
                    final today = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: today.subtract(const Duration(days: 30)),
                      lastDate: today.add(const Duration(days: 90)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: TxaTheme.accent,
                              onPrimary: Colors.black,
                              surface: TxaTheme.secondaryBg,
                              onSurface: Colors.white,
                            ),
                            dialogTheme: const DialogThemeData(
                              backgroundColor: TxaTheme.primaryBg,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (selected != null) {
                      setState(() {
                        _selectedDate = selected;
                        _selectedDayIndex = 0;
                      });
                      final dateStr = DateFormat('yyyy-MM-dd').format(selected);
                      _fetchSchedule(date: dateStr);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: TxaTheme.accent),
              ),
            )
          else if (_scheduleDays.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_rounded, color: TxaTheme.textMuted, size: 54),
                    SizedBox(height: 16),
                    Text(
                      'Chưa có lịch chiếu nào.',
                      style: TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Horizontal calendar day picker
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _scheduleDays.length,
                itemBuilder: (context, idx) {
                  final dayData = _scheduleDays[idx];
                  final isSelected = idx == _selectedDayIndex;
                  final formattedDate = _formatDateHeader(dayData['date'] ?? '');

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(
                        formattedDate,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: TxaTheme.accent,
                      backgroundColor: TxaTheme.secondaryBg.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? TxaTheme.accent : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDayIndex = idx;
                            try {
                              _selectedDate = DateTime.parse(dayData['date'] ?? '');
                            } catch (_) {}
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Movies List for selected Day
            Expanded(
              child: _buildMoviesListForDay(_scheduleDays[_selectedDayIndex]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoviesListForDay(dynamic dayData) {
    final movies = dayData['movies'] as List? ?? [];
    if (movies.isEmpty) {
      return const Center(
        child: Text(
          'Không có phim phát sóng ngày này.',
          style: TextStyle(color: TxaTheme.textMuted, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
      itemCount: movies.length,
      itemBuilder: (context, idx) {
        final movie = movies[idx];
        final name = movie['name'] ?? '';
        final thumbUrl = movie['thumb_url'] ?? '';
        final nextEp = movie['next_episode_name'] ?? '';
        final currentEp = movie['episode_current'] ?? '';
        final time = movie['broadcast_time'] ?? '';
        final quality = movie['quality'] ?? 'FHD';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: TxaTheme.liquidGlassPill(
            radius: 20,
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => MovieDetailScreen(slug: movie['slug'] ?? ''),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(color: TxaTheme.cardBg),
                      errorWidget: (c, u, e) => Container(color: TxaTheme.cardBg),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TxaTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, color: TxaTheme.accent, size: 12),
                          const SizedBox(width: 4),
                        Text(
                            time,
                            style: GoogleFonts.outfit(
                              color: TxaTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quality,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${TxaLanguage.t('current_episode')}: $currentEp • $nextEp',
                      style: GoogleFonts.outfit(color: TxaTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
