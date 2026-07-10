import 'package:flutter/material.dart';
import '../services/txa_api.dart';
import '../services/txa_language.dart';
import '../theme/txa_theme.dart';
import '../utils/txa_toast.dart';
import 'txa_profile_screen.dart';

class TxaPaymentHistoryScreen extends StatefulWidget {
  const TxaPaymentHistoryScreen({super.key});

  @override
  State<TxaPaymentHistoryScreen> createState() => _TxaPaymentHistoryScreenState();
}

class _TxaPaymentHistoryScreenState extends State<TxaPaymentHistoryScreen> {
  List<dynamic> _allPayments = [];
  List<dynamic> _displayPayments = [];
  bool _loading = true;
  String? _error;
  int _displayCount = 15;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          _displayCount < _allPayments.length) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await TxaApi().getPayments();
      setState(() {
        _allPayments = res;
        _displayCount = 15;
        _updateDisplayList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
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

  void _loadMore() {
    setState(() {
      _displayCount = (_displayCount + 15).clamp(0, _allPayments.length);
      _updateDisplayList();
    });
  }

  void _updateDisplayList() {
    if (_allPayments.isEmpty) {
      _displayPayments = [];
    } else {
      final end = _displayCount.clamp(0, _allPayments.length);
      _displayPayments = _allPayments.sublist(0, end);
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
          TxaLanguage.t('billing_history'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: TxaTheme.accent,
        backgroundColor: TxaTheme.cardBg,
        child: _displayPayments.isEmpty && _loading
            ? const Center(
                child: CircularProgressIndicator(color: TxaTheme.accent),
              )
            : _error != null && _displayPayments.isEmpty
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
                          onPressed: _loadData,
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
                : _displayPayments.isEmpty
                    ? Center(
                        child: Text(
                          TxaLanguage.t('no_payments_yet'),
                          style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _displayPayments.length + (_displayCount < _allPayments.length ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _displayPayments.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(color: TxaTheme.accent)),
                            );
                          }

                          final log = _displayPayments[index];
                          final title = log['packageTitle'] ?? 'Gói VIP';
                          final price = NumberFormatCurrency.format(log['price']);
                          final status = log['status']?.toString().toLowerCase() ?? 'pending';
                          final date = log['date'] != null ? log['date'].toString().split('T')[0] : '';
                          final txid = log['txid'] ?? '';
                          final note = log['note'] ?? '';
                          
                          Color statusColor = Colors.orangeAccent;
                          String statusLabel = TxaLanguage.t('status_pending');
                          if (status == 'approved') {
                            statusColor = Colors.greenAccent;
                            statusLabel = TxaLanguage.t('status_approved');
                          } else if (status == 'rejected') {
                            statusColor = Colors.redAccent;
                            statusLabel = TxaLanguage.t('status_rejected');
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        price,
                                        style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.w900),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Giao dịch: $txid',
                                        style: const TextStyle(color: TxaTheme.textSecondary, fontSize: 12),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (note.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ghi chú: $note',
                                      style: const TextStyle(color: TxaTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ngày tạo: $date',
                                    style: const TextStyle(color: TxaTheme.textMuted, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
