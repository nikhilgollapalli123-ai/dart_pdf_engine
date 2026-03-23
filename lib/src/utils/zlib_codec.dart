import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Zlib compression/decompression utilities for PDF streams.
///
/// Uses `package:archive` for cross-platform compatibility (including web).
class ZlibCodec {
  ZlibCodec._();

  /// Compress data using Deflate (for FlateDecode filter).
  static Uint8List compress(Uint8List data) {
    final compressed = const ZLibEncoder().encode(data);
    return Uint8List.fromList(compressed);
  }

  /// Decompress data compressed with Deflate.
  static Uint8List decompress(Uint8List data) {
    try {
      final decompressed = const ZLibDecoder().decodeBytes(data);
      return Uint8List.fromList(decompressed);
    } catch (_) {
      // Try raw deflate if zlib header is missing.
      try {
        final decompressed = Inflate(data).getBytes();
        return Uint8List.fromList(decompressed);
      } catch (_) {
        return data;
      }
    }
  }
}
