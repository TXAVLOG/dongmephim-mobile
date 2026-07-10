import 'package:flutter/material.dart';
import '../services/txa_language.dart';
import '../utils/txa_platform.dart';
import '../tv/widgets/tv_focusable_card.dart';
import '../tv/navigation/tv_focus_system.dart';

class TxaErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const TxaErrorWidget({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final String errorTitle = TxaLanguage.t('error_connection');
    final String errorDesc = message ?? (TxaLanguage.currentLang == 'vi'
        ? 'Lỗi kết nối máy chủ. Vui lòng kiểm tra lại mạng hoặc thử lại sau.'
        : 'Server connection error. Please check your network or try again later.');

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // CustomPaint Disconnected Cables Icon
            SizedBox(
              width: 180,
              height: 100,
              child: CustomPaint(
                painter: _DisconnectedCablesPainter(),
              ),
            ),
            const SizedBox(height: 24),

            // Error Title
            Text(
              errorTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Error Description
            Text(
              errorDesc,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13.5,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Retry Button (D-pad focusable for TV, elevated for mobile/desktop)
            if (onRetry != null) _buildRetryButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    final btnText = TxaLanguage.t('retry');

    if (TxaPlatform.isTV) {
      final focusNode = TvFocusSystem.getNode('error_retry_btn');
      return SizedBox(
        width: 160,
        height: 46,
        child: TvFocusableCard(
          focusNode: focusNode,
          onTap: onRetry!,
          scaleOnFocus: 1.06,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: const Color(0xFF737DFD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text(
                  btnText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: Text(btnText),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF737DFD),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13.5,
        ),
        elevation: 4,
      ),
    );
  }
}

class _DisconnectedCablesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    
    // Draw cable lines
    final cablePaint = Paint()
      ..color = const Color(0xFF475569) // Dark Slate Gray
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final plugPaint = Paint()
      ..color = const Color(0xFF94A3B8) // Light Slate Gray
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = const Color(0xFF737DFD) // Accent Blue
      ..style = PaintingStyle.fill;

    final prongPaint = Paint()
      ..color = const Color(0xFFCBD5E1) // Silver
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    final sparkPaint = Paint()
      ..color = const Color(0xFFF59E0B) // Amber
      ..style = PaintingStyle.fill;

    // LEFT CABLE & PLUG
    // 1. Line
    final leftPath = Path()
      ..moveTo(0, midY)
      ..cubicTo(size.width * 0.1, midY + 12, size.width * 0.2, midY - 6, size.width * 0.3, midY);
    canvas.drawPath(leftPath, cablePaint);

    // 2. Plug Body
    final leftPlugRect = Rect.fromLTWH(size.width * 0.3, midY - 10, 24, 20);
    canvas.drawRRect(RRect.fromRectAndRadius(leftPlugRect, const Radius.circular(5)), plugPaint);
    
    // 3. Colored Band on Plug
    final leftBandRect = Rect.fromLTWH(size.width * 0.3, midY - 10, 6, 20);
    canvas.drawRRect(RRect.fromRectAndCorners(
      leftBandRect,
      topLeft: const Radius.circular(5),
      bottomLeft: const Radius.circular(5),
    ), accentPaint);

    // 4. Prongs (Disconnected - sticking out to the right)
    canvas.drawLine(Offset(size.width * 0.3 + 24, midY - 4), Offset(size.width * 0.3 + 32, midY - 4), prongPaint);
    canvas.drawLine(Offset(size.width * 0.3 + 24, midY + 4), Offset(size.width * 0.3 + 32, midY + 4), prongPaint);

    // RIGHT CABLE & PLUG
    // 1. Line
    final rightPath = Path()
      ..moveTo(size.width, midY)
      ..cubicTo(size.width * 0.9, midY - 12, size.width * 0.8, midY + 6, size.width * 0.7, midY);
    canvas.drawPath(rightPath, cablePaint);

    // 2. Plug Body
    final rightPlugRect = Rect.fromLTWH(size.width * 0.58, midY - 10, 24, 20);
    canvas.drawRRect(RRect.fromRectAndRadius(rightPlugRect, const Radius.circular(5)), plugPaint);

    // 3. Colored Band on Plug
    final rightBandRect = Rect.fromLTWH(size.width * 0.68, midY - 10, 6, 20);
    canvas.drawRRect(RRect.fromRectAndCorners(
      rightBandRect,
      topRight: const Radius.circular(5),
      bottomRight: const Radius.circular(5),
    ), accentPaint);

    // 4. Sockets (recessed holes on the left side of the right plug)
    final socketPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.58 + 4, midY - 4), 2.2, socketPaint);
    canvas.drawCircle(Offset(size.width * 0.58 + 4, midY + 4), 2.2, socketPaint);

    // SPARKS / EXPLOSION INDICATION IN THE GAP
    final double gapCenterX = size.width * 0.49;
    
    // Draw lightning spark
    final sparkPath = Path()
      ..moveTo(gapCenterX - 3, midY - 24)
      ..lineTo(gapCenterX + 6, midY - 4)
      ..lineTo(gapCenterX - 4, midY + 2)
      ..lineTo(gapCenterX + 4, midY + 24)
      ..lineTo(gapCenterX - 6, midY + 4)
      ..lineTo(gapCenterX + 3, midY - 2)
      ..close();
    canvas.drawPath(sparkPath, sparkPaint);

    // Minor spark particles
    canvas.drawCircle(Offset(gapCenterX - 14, midY - 14), 2.5, sparkPaint);
    canvas.drawCircle(Offset(gapCenterX + 16, midY + 12), 2.0, sparkPaint);
    canvas.drawCircle(Offset(gapCenterX - 18, midY + 8), 1.5, sparkPaint);
    canvas.drawCircle(Offset(gapCenterX + 12, midY - 16), 1.8, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
