import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import '../../../utils/txa_logger.dart';

class TxaMergeEngine {
  /// Merge downloaded HLS segments into final video (MP4 or TS)
  static Future<File?> merge({
    required Directory baseDir,
    required File outputFile,
    bool enableWatermark = true,
  }) async {
    final playlistFile = File(p.join(baseDir.path, 'playlist.m3u8'));
    if (!await playlistFile.exists()) {
      TxaLogger.log('Merge failed: playlist.m3u8 not found at ${baseDir.path}', type: 'app');
      return null;
    }

    // 1. Try FFmpeg merge on Mobile (Android / iOS)
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final ffmpegResult = await _mergeWithFfmpeg(
          baseDir: baseDir,
          outputFile: outputFile,
          enableWatermark: enableWatermark,
        );
        if (ffmpegResult != null && await ffmpegResult.exists() && (await ffmpegResult.length()) > 1024) {
          await _cleanupSegments(baseDir);
          return ffmpegResult;
        }
      } catch (e) {
        TxaLogger.log('FFmpeg merge error, falling back to binary concatenation: $e', type: 'app');
      }
    }

    // 2. Fast Binary Concatenation Fallback (Windows / TV / Fallback)
    try {
      final binaryResult = await _mergeBinaryFast(baseDir: baseDir, outputFile: outputFile);
      if (binaryResult != null && await binaryResult.exists()) {
        await _cleanupSegments(baseDir);
        return binaryResult;
      }
    } catch (e) {
      TxaLogger.log('Binary merge error: $e', type: 'app');
    }

    // 3. Last fallback: return local playlist.m3u8 itself for direct HLS playback
    return playlistFile;
  }

  static Future<File?> _mergeWithFfmpeg({
    required Directory baseDir,
    required File outputFile,
    required bool enableWatermark,
  }) async {
    final playlistPath = p.join(baseDir.path, 'playlist.m3u8');
    final outPath = outputFile.path.endsWith('.mp4') ? outputFile.path : '${outputFile.path}.mp4';

    // Prepare watermark file if enabled
    String? watermarkPath;
    if (enableWatermark) {
      try {
        final byteData = await rootBundle.load('assets/logo.png');
        final wmFile = File(p.join(baseDir.path, 'watermark.png'));
        await wmFile.writeAsBytes(byteData.buffer.asUint8List());
        watermarkPath = wmFile.path;
      } catch (_) {}
    }

    String command;
    if (watermarkPath != null && File(watermarkPath).existsSync()) {
      // Remux + Overlay Watermark
      command =
          '-y -allowed_extensions ALL -i "$playlistPath" -i "$watermarkPath" -filter_complex "overlay=W-w-20:H-h-20" -c:v libx264 -preset veryfast -crf 23 -c:a copy "$outPath"';
    } else {
      // Fast Stream Copy (0s transcoding)
      command =
          '-y -allowed_extensions ALL -i "$playlistPath" -c copy -bsf:a aac_adtstoasc "$outPath"';
    }

    TxaLogger.log('Executing FFmpeg command: $command', type: 'app');
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final finalFile = File(outPath);
      if (await finalFile.exists() && (await finalFile.length()) > 1024) {
        return finalFile;
      }
    }

    // If remux failed with filter, try simple stream copy
    if (watermarkPath != null) {
      final simpleCmd =
          '-y -allowed_extensions ALL -i "$playlistPath" -c copy -bsf:a aac_adtstoasc "$outPath"';
      final simpleSession = await FFmpegKit.execute(simpleCmd);
      final simpleCode = await simpleSession.getReturnCode();
      if (ReturnCode.isSuccess(simpleCode)) {
        final finalFile = File(outPath);
        if (await finalFile.exists() && (await finalFile.length()) > 1024) {
          return finalFile;
        }
      }
    }

    return null;
  }

  /// Fast binary concatenation of .ts files into a single video container in < 1 second
  static Future<File?> _mergeBinaryFast({
    required Directory baseDir,
    required File outputFile,
  }) async {
    final outPath = outputFile.path.endsWith('.ts') ? outputFile.path : '${p.withoutExtension(outputFile.path)}.ts';
    final targetFile = File(outPath);
    final sink = targetFile.openWrite(mode: FileMode.write);

    final entries = baseDir.listSync().whereType<File>().toList();
    final segFiles = entries
        .where((f) => p.basename(f.path).startsWith('seg_') && f.path.endsWith('.ts'))
        .toList();

    segFiles.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    if (segFiles.isEmpty) {
      await sink.close();
      return null;
    }

    for (final seg in segFiles) {
      final bytes = await seg.readAsBytes();
      sink.add(bytes);
    }

    await sink.flush();
    await sink.close();

    if (await targetFile.exists() && (await targetFile.length()) > 1024) {
      return targetFile;
    }
    return null;
  }

  /// Clean up intermediate segment files to reclaim storage
  static Future<void> _cleanupSegments(Directory baseDir) async {
    try {
      final files = baseDir.listSync().whereType<File>();
      for (final file in files) {
        final name = p.basename(file.path);
        if (name.startsWith('seg_') && (name.endsWith('.ts') || name.endsWith('.tmp'))) {
          await file.delete();
        } else if (name == 'watermark.png') {
          await file.delete();
        }
      }
    } catch (e) {
      TxaLogger.log('Segment cleanup error: $e', type: 'app');
    }
  }
}
