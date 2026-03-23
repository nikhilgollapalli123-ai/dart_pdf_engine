import 'dart:io';
import 'dart:typed_data';

/// Zlib compression/decompression utilities for PDF streams.
class ZlibCodec {
  ZlibCodec._();

  /// Compress data using Deflate (for FlateDecode filter).
  static Uint8List compress(Uint8List data) {
    final codec = ZLibCodec();
    return Uint8List.fromList(codec.encode(data));
  }

  /// Decompress data compressed with Deflate.
  static Uint8List decompress(Uint8List data) {
    final codec = ZLibCodec();
    return Uint8List.fromList(codec.decode(data));
  }
}
