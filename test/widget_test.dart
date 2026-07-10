import 'package:flutter_test/flutter_test.dart';
import 'package:tphimx_setup/utils/txa_format.dart';

void main() {
  group('TxaFormat Unit Tests', () {
    test('pad2 should pad single digits correctly', () {
      expect(TxaFormat.pad2(5), '05');
      expect(TxaFormat.pad2(10), '10');
    });

    test('formatTime should format seconds into MM:SS or HH:MM:SS', () {
      expect(TxaFormat.formatTime(0), '00:00');
      expect(TxaFormat.formatTime(65), '01:05');
      expect(TxaFormat.formatTime(3665), '01:01:05');
    });

    test('formatFileSize should format bytes into human readable format', () {
      expect(TxaFormat.formatFileSize(0), '0.00 B');
      expect(TxaFormat.formatFileSize(1024), '1.00 KB');
      expect(TxaFormat.formatFileSize(1048576), '1.00 MB');
    });
  });
}
