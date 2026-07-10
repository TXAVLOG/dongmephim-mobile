import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../theme/txa_theme.dart';
import '../services/txa_api.dart';
import '../services/txa_auth_service.dart';
import '../utils/txa_toast.dart';
import '../services/txa_language.dart';
import 'txa_tv_confirm_screen.dart';

class TxaQrScanScreen extends StatefulWidget {
  const TxaQrScanScreen({super.key});

  @override
  State<TxaQrScanScreen> createState() => _TxaQrScanScreenState();
}

class _TxaQrScanScreenState extends State<TxaQrScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasPermission = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
    } else {
      final request = await Permission.camera.request();
      setState(() {
        _hasPermission = request.isGranted;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    // Check custom scheme txa://
    if (!code.startsWith('txa://')) {
      return; // Ignore other QR codes
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Parse QR token: txa://{qr_token}?t={timestamp}&d={device_id}
      final uri = Uri.parse(code.replaceFirst('txa://', 'http://placeholder/'));
      final qrToken = uri.path.replaceAll('/', '');

      if (qrToken.isEmpty) {
        TxaToast.show(context, TxaLanguage.t('qr_invalid'), isError: true);
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      await _pairByQrToken(qrToken);
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('qr_read_error', replace: {'error': e.toString()}), isError: true);
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pairByQrToken(String qrToken) async {
    final token = TxaAuthService().token;
    if (token == null) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('login_on_phone_first'), isError: true);
        Navigator.pop(context);
      }
      return;
    }

    final url = Uri.parse('${TxaApi.baseUrl}/api/app/tv-pair');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TXA-API-KEY': TxaApi.apiKey,
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'action': 'pair_by_qr',
          'qr_token': qrToken,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          final sessionId = data['session_id'];
          final tvDevice = data['tv_device'];

          if (mounted) {
            // Push to confirm screen
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TxaTvConfirmScreen(
                  sessionId: sessionId,
                  tvDevice: tvDevice,
                ),
              ),
            );
          }
          return;
        } else {
          if (mounted) {
            TxaToast.show(context, body['message'] ?? TxaLanguage.t('qr_scan_failed'), isError: true);
          }
        }
      } else {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          TxaToast.show(context, body['message'] ?? TxaLanguage.t('qr_expired'), isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        TxaToast.show(context, TxaLanguage.t('server_conn_error', replace: {'error': e.toString()}), isError: true);
      }
    }

    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(TxaLanguage.t('tv_scan_qr_title_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    TxaLanguage.t('camera_permission_denied'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _checkCameraPermission,
                    style: ElevatedButton.styleFrom(backgroundColor: TxaTheme.accent),
                    child: Text(TxaLanguage.t('grant_camera_permission'), style: const TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Scanner view
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),

                // Dark Mask overlay around viewport
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),

                // Center viewport cutout
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: TxaTheme.accent, width: 3),
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.transparent,
                    ),
                  ),
                ),

                // Processing loader
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(color: TxaTheme.accent),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

