import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_logger.dart';
import '../utils/txa_toast.dart';
import '../services/txa_language.dart';
import '../services/txa_version.dart';

class LogEntry {
  final String timestamp;
  final String type;
  final String message;
  final String rawLine;

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.rawLine,
  });
}

class ParsedApiLog {
  final String method;
  final String url;
  final String status;
  final String? responseBody;

  ParsedApiLog({
    required this.method,
    required this.url,
    required this.status,
    this.responseBody,
  });
}

class TxaLogViewerScreen extends StatefulWidget {
  const TxaLogViewerScreen({super.key});

  @override
  State<TxaLogViewerScreen> createState() => _TxaLogViewerScreenState();
}

class _TxaLogViewerScreenState extends State<TxaLogViewerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _logTypes = ['all', 'api', 'downloader', 'crash'];
  final List<String> _tabNames = ['Tất Cả', 'API', 'Tải Xuống', 'Lỗi/Crash'];
  List<LogEntry> _parsedEntries = [];
  bool _isLoading = false;
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _logTypes.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLogs();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _expandedIndices.clear();
    });
    final activeType = _logTypes[_tabController.index];
    final content = await TxaLogger.readLogs(activeType);
    
    // Parse string content into structured list of LogEntry
    final entries = _parseLogs(content);

    setState(() {
      _parsedEntries = entries;
      _isLoading = false;
    });
  }

  List<LogEntry> _parseLogs(String content) {
    if (content.trim().isEmpty || content.trim() == 'Chưa có nhật ký nào cho loại này.') {
      return [];
    }
    final List<LogEntry> list = [];
    final lines = content.split('\n');
    final headerRegExp = RegExp(r'^\[(\d{2}:\d{2}:\d{2}\.\d{3})\]\s+\[([A-Z_]+)\]\s+(.*)$');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = headerRegExp.firstMatch(trimmed);
      if (match != null) {
        final timestamp = match.group(1)!;
        final type = match.group(2)!;
        final message = match.group(3)!;
        
        list.add(LogEntry(
          timestamp: timestamp,
          type: type,
          message: message,
          rawLine: trimmed,
        ));
      } else {
        if (list.isNotEmpty) {
          final lastEntry = list.last;
          final updatedMessage = '${lastEntry.message}\n$trimmed';
          final updatedRaw = '${lastEntry.rawLine}\n$trimmed';
          
          list[list.length - 1] = LogEntry(
            timestamp: lastEntry.timestamp,
            type: lastEntry.type,
            message: updatedMessage,
            rawLine: updatedRaw,
          );
        } else {
          list.add(LogEntry(
            timestamp: '--:--:--',
            type: 'APP',
            message: trimmed,
            rawLine: trimmed,
          ));
        }
      }
    }
    return list.reversed.toList();
  }

  ParsedApiLog? _tryParseApiLog(String message) {
    try {
      final lines = message.split('\n');
      final firstLine = lines.first.trim();
      
      final apiRegExp = RegExp(r'^([A-Z]+)\s+(\S+)\s+-\s+STATUS:\s+(.*)$');
      final match = apiRegExp.firstMatch(firstLine);
      if (match == null) return null;
      
      final method = match.group(1)!;
      final url = match.group(2)!;
      final status = match.group(3)!;
      
      String? responseBody;
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('[response]')) {
          responseBody = line.substring('[response]'.length).trim();
          break;
        }
      }
      
      return ParsedApiLog(
        method: method,
        url: url,
        status: status,
        responseBody: responseBody,
      );
    } catch (_) {}
    return null;
  }

  String _cleanUrlForUi(String text) {
    return text.replaceAll(RegExp(r'https?://[^/\s]+'), '');
  }

  Widget _buildApiLogExpanded(ParsedApiLog apiLog) {
    final bool isSuccess = apiLog.status == '200';
    final statusColor = isSuccess ? Colors.greenAccent : Colors.redAccent;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: 12),
        
        // Status & Method
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                apiLog.method,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'STATUS: ${apiLog.status}',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        
        // URL API
        Text(
          TxaLanguage.t('api_url_label'),
          style: const TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: SelectableText(
            _cleanUrlForUi(apiLog.url),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 14),
        
        // Response Body
        if (apiLog.responseBody != null) ...[
          Row(
            children: [
              const Text(
                'DỮ LIỆU PHẢN HỒI (RESPONSE BODY)',
                style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildJsonCopyChip(apiLog.responseBody!),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: _buildFormattedResponse(apiLog.responseBody!),
          ),
        ],
      ],
    );
  }

  Widget _buildJsonCopyChip(String body) {
    try {
      jsonDecode(body);
      return GestureDetector(
        onTap: () {
          try {
            final pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
            Clipboard.setData(ClipboardData(text: pretty));
            TxaToast.show(context, 'Đã copy JSON đẹp');
          } catch (_) {}
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, color: Colors.purpleAccent, size: 10),
              SizedBox(width: 3),
              Text('Copy JSON', style: TextStyle(color: Colors.purpleAccent, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildFormattedResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      return SelectableText.rich(
        _highlightJson(pretty),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
      );
    } catch (_) {
      return SelectableText(
        body,
        style: const TextStyle(color: Colors.greenAccent, fontSize: 11.5, fontFamily: 'monospace', height: 1.35),
      );
    }
  }

  TextSpan _highlightJson(String json) {
    final spans = <TextSpan>[];
    final lines = json.split('\n');
    for (var i = 0; i < lines.length; i++) {
      _highlightJsonLine(lines[i], spans);
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return TextSpan(children: spans);
  }

  void _highlightJsonLine(String line, List<TextSpan> spans) {
    final kvMatch = RegExp(r'^(\s*)"([^"]+)"(\s*:\s*)(.*)$').firstMatch(line);
    if (kvMatch != null) {
      final indent = kvMatch.group(1)!;
      final key = kvMatch.group(2)!;
      final colon = kvMatch.group(3)!;
      final value = kvMatch.group(4)!;
      if (indent.isNotEmpty) spans.add(TextSpan(text: indent, style: const TextStyle(color: Colors.white54)));
      spans.add(TextSpan(text: '"$key"', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600)));
      spans.add(TextSpan(text: colon, style: const TextStyle(color: Colors.white38)));
      _highlightJsonValue(value, spans);
      return;
    }
    final arrayMatch = RegExp(r'^(\s*)(.*)$').firstMatch(line);
    if (arrayMatch != null) {
      final indent = arrayMatch.group(1)!;
      final content = arrayMatch.group(2)!;
      if (indent.isNotEmpty) spans.add(TextSpan(text: indent, style: const TextStyle(color: Colors.white54)));
      _highlightJsonValue(content, spans);
    }
  }

  void _highlightJsonValue(String value, List<TextSpan> spans) {
    final trimmed = value.trimRight();
    final trailing = value.substring(trimmed.length);
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      spans.add(TextSpan(text: trimmed, style: const TextStyle(color: Colors.greenAccent)));
    } else if (trimmed == 'true' || trimmed == 'false') {
      spans.add(TextSpan(text: trimmed, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)));
    } else if (trimmed == 'null') {
      spans.add(TextSpan(text: trimmed, style: const TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic)));
    } else if (RegExp(r'^-?\d+\.?\d*$').hasMatch(trimmed)) {
      spans.add(TextSpan(text: trimmed, style: const TextStyle(color: Colors.yellowAccent)));
    } else {
      spans.add(TextSpan(text: value, style: const TextStyle(color: Colors.white70)));
      return;
    }
    if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing, style: const TextStyle(color: Colors.white30)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildLogItem(LogEntry entry, int index) {
    Color typeColor = Colors.blueAccent;
    IconData typeIcon = Icons.terminal_rounded;

    final typeUpper = entry.type.toUpperCase();
    if (typeUpper.contains('API')) {
      typeColor = Colors.greenAccent;
      typeIcon = Icons.api_rounded;
    } else if (typeUpper.contains('DOWNLOAD') || typeUpper.contains('DOWN')) {
      typeColor = Colors.orangeAccent;
      typeIcon = Icons.download_rounded;
    } else if (typeUpper.contains('CRASH') || typeUpper.contains('ERR')) {
      typeColor = Colors.redAccent;
      typeIcon = Icons.bug_report_rounded;
    } else if (typeUpper.contains('APP')) {
      typeColor = Colors.cyanAccent;
      typeIcon = Icons.phonelink_setup_rounded;
    }

    final isExpanded = _expandedIndices.contains(index);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedIndices.remove(index);
          } else {
            _expandedIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isExpanded ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? typeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, color: typeColor, size: 16),
            ),
            const SizedBox(width: 12),
            
            // Timestamp & Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Time Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.timestamp,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type tag
                      Text(
                        entry.type,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedCrossFade(
                    firstChild: Text(
                      _cleanUrlForUi(entry.message.split('\n').first),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    secondChild: () {
                      final apiLog = _tryParseApiLog(entry.message);
                      if (apiLog != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              _cleanUrlForUi(entry.message.split('\n').first),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _buildApiLogExpanded(apiLog),
                          ],
                        );
                      }
                      return SelectableText(
                        entry.message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      );
                    }(),
                    crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Interactive Copy Button
            _CopyButton(entry: entry),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeType = _logTypes[_tabController.index];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Nhật Ký Hệ Thống',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: TxaTheme.accent),
            onPressed: () async {
              await TxaLogger.shareLogs(activeType);
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              TxaToast.show(context, TxaLanguage.t('log_sharing_prep'));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            onPressed: () async {
              await TxaLogger.clearLogs();
              await _loadLogs();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              TxaToast.show(context, TxaLanguage.t('log_cleared'));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TxaTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          dividerColor: Colors.transparent,
          tabs: _tabNames.map((name) => Tab(text: name)).toList(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 90.0, top: 10.0),
        child: TxaTheme.liquidGlassPill(
          radius: 20,
          padding: const EdgeInsets.all(12.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: TxaTheme.accent))
              : _parsedEntries.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có nhật ký nào cho loại này.',
                        style: TextStyle(color: TxaTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _parsedEntries.length,
                      itemBuilder: (context, index) {
                        return _buildLogItem(_parsedEntries[index], index);
                      },
                    ),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final LogEntry entry;
  const _CopyButton({required this.entry});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    _animController.forward(from: 0.0);
    setState(() {
      _isCopied = true;
    });

    final now = DateTime.now();
    final systemTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final osName = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;

    final clipboardText = '''
=========================================
      DONGMEPHIM SYSTEM DEBUG LOG
=========================================
• Thời Gian: $systemTime
• Thiết Bị: $osName ($osVersion)
• Phiên Bản App: ${TxaVersion.version}
• Loại Nhật Ký: ${widget.entry.type}
• Mốc Log: ${widget.entry.timestamp}
• Trạng Thái: SUCCESS

• Nội Dung Chi Tiết:
${widget.entry.message}

• Dòng Log Gốc:
${widget.entry.rawLine}
=========================================
''';

    try {
      await Clipboard.setData(ClipboardData(text: clipboardText));
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('log_copied'), isError: false);
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('log_copy_failed', replace: {'error': e.toString()}), isError: true);
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isCopied = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.8).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      ),
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: _isCopied
              ? const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.greenAccent,
                  key: ValueKey('copied'),
                  size: 18,
                )
              : const Icon(
                  Icons.copy_rounded,
                  color: Colors.white54,
                  key: ValueKey('copy'),
                  size: 18,
                ),
        ),
        onPressed: _handleCopy,
      ),
    );
  }
}
