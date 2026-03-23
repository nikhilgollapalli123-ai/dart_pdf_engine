import 'dart:convert';
import 'dart:typed_data';
import '../pdf_objects.dart';
import '../pdf_stream.dart';

/// Represents a bitmap image (JPEG or PNG) for embedding in PDF.
class PdfBitmap {
  final Uint8List _data;
  late final int width;
  late final int height;
  late final _ImageFormat _format;
  bool _hasAlpha = false;

  /// Create from raw image bytes (JPEG or PNG).
  PdfBitmap(this._data) {
    _detect();
  }

  /// Create from a base64-encoded string.
  factory PdfBitmap.fromBase64(String base64Data) {
    return PdfBitmap(base64Decode(base64Data));
  }

  /// Get the raw image data.
  Uint8List get imageData => _data;

  /// Whether this is a JPEG.
  bool get isJpeg => _format == _ImageFormat.jpeg;

  /// Whether this is a PNG.
  bool get isPng => _format == _ImageFormat.png;

  /// Whether the image has an alpha channel.
  bool get hasAlpha => _hasAlpha;

  void _detect() {
    if (_data.length < 8) {
      throw ArgumentError('Image data too small');
    }

    // Check for JPEG (SOI marker: 0xFF 0xD8).
    if (_data[0] == 0xFF && _data[1] == 0xD8) {
      _format = _ImageFormat.jpeg;
      _parseJpegDimensions();
      return;
    }

    // Check for PNG (signature: 89 50 4E 47 0D 0A 1A 0A).
    if (_data[0] == 0x89 &&
        _data[1] == 0x50 &&
        _data[2] == 0x4E &&
        _data[3] == 0x47) {
      _format = _ImageFormat.png;
      _parsePngHeader();
      return;
    }

    throw ArgumentError('Unsupported image format. Only JPEG and PNG are supported.');
  }

  void _parseJpegDimensions() {
    int offset = 2;
    while (offset < _data.length - 1) {
      if (_data[offset] != 0xFF) {
        offset++;
        continue;
      }
      final marker = _data[offset + 1];

      // SOFn markers (Start of Frame).
      if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xCC) {
        if (offset + 9 < _data.length) {
          final bd = ByteData.view(_data.buffer, _data.offsetInBytes);
          height = bd.getUint16(offset + 5);
          width = bd.getUint16(offset + 7);
          return;
        }
      }

      // Skip to the next marker.
      if (offset + 3 < _data.length) {
        final bd = ByteData.view(_data.buffer, _data.offsetInBytes);
        final length = bd.getUint16(offset + 2);
        offset += 2 + length;
      } else {
        break;
      }
    }

    // Fallback.
    width = 1;
    height = 1;
  }

  void _parsePngHeader() {
    // IHDR chunk starts at offset 8 (after signature).
    if (_data.length < 24) {
      width = 1;
      height = 1;
      return;
    }

    final bd = ByteData.view(_data.buffer, _data.offsetInBytes);
    width = bd.getUint32(16);
    height = bd.getUint32(20);

    // Check color type for alpha.
    if (_data.length > 25) {
      final colorType = _data[25];
      _hasAlpha = (colorType == 4 || colorType == 6); // Greyscale+A or RGBA.
    }
  }

  /// Build the PDF image XObject stream.
  PdfStream toImageStream() {
    final stream = PdfStream(compress: false);
    final dict = stream.dictionary;

    dict.set('Type', PdfName('XObject'));
    dict.set('Subtype', PdfName('Image'));
    dict.set('Width', PdfNumber(width));
    dict.set('Height', PdfNumber(height));

    if (isJpeg) {
      dict.set('ColorSpace', PdfName('DeviceRGB'));
      dict.set('BitsPerComponent', PdfNumber(8));
      dict.set('Filter', PdfName('DCTDecode'));
      stream.data = _data;
    } else if (isPng) {
      // For PNG, we embed the raw data with FlateDecode.
      dict.set('ColorSpace', PdfName('DeviceRGB'));
      dict.set('BitsPerComponent', PdfNumber(8));
      dict.set('Filter', PdfName('FlateDecode'));
      // Extract the raw IDAT data.
      final rawData = _extractPngImageData();
      stream.data = rawData;
    }

    return stream;
  }

  Uint8List _extractPngImageData() {
    // Collect all IDAT chunk data.
    final idatData = <int>[];
    int offset = 8; // Skip PNG signature.

    while (offset + 8 <= _data.length) {
      final bd = ByteData.view(_data.buffer, _data.offsetInBytes);
      final chunkLength = bd.getUint32(offset);
      final chunkType =
          String.fromCharCodes(_data.sublist(offset + 4, offset + 8));

      if (chunkType == 'IDAT') {
        if (offset + 8 + chunkLength <= _data.length) {
          idatData.addAll(_data.sublist(offset + 8, offset + 8 + chunkLength));
        }
      }

      // Move to next chunk (length + type + data + CRC).
      offset += 12 + chunkLength;
    }

    return Uint8List.fromList(idatData);
  }
}

enum _ImageFormat { jpeg, png }
