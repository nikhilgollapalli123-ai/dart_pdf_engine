import 'dart:typed_data';
import 'pdf_objects.dart';
import 'utils/zlib_codec.dart';

/// A PDF stream object — dictionary + binary data.
class PdfStream extends PdfObject {
  final PdfDictionary dictionary;
  Uint8List _data;
  final bool compress;

  PdfStream({
    PdfDictionary? dictionary,
    Uint8List? data,
    this.compress = true,
  })  : dictionary = dictionary ?? PdfDictionary(),
        _data = data ?? Uint8List(0);

  Uint8List get data => _data;
  set data(Uint8List value) => _data = value;

  @override
  void writeTo(StringBuffer buffer) {
    Uint8List outputData;
    final dict = PdfDictionary(Map.from(dictionary.entries));

    if (compress && _data.isNotEmpty) {
      outputData = ZlibCodec.compress(_data);
      dict.set('Filter', PdfName('FlateDecode'));
    } else {
      outputData = _data;
    }

    dict.set('Length', PdfNumber(outputData.length));
    dict.writeTo(buffer);
    buffer.write('\nstream\n');
    // Stream data will be written as binary — mark position.
    // We use a special placeholder that PdfWriter will handle.
    buffer.write(String.fromCharCodes(outputData));
    buffer.write('\nendstream');
  }

  /// Write to bytes directly (for binary-safe output).
  List<int> toBytes() {
    Uint8List outputData;
    final dict = PdfDictionary(Map.from(dictionary.entries));

    if (compress && _data.isNotEmpty) {
      outputData = ZlibCodec.compress(_data);
      dict.set('Filter', PdfName('FlateDecode'));
    } else {
      outputData = _data;
    }

    dict.set('Length', PdfNumber(outputData.length));

    final headerBuffer = StringBuffer();
    dict.writeTo(headerBuffer);

    final List<int> bytes = [];
    bytes.addAll(headerBuffer.toString().codeUnits);
    bytes.addAll('\nstream\n'.codeUnits);
    bytes.addAll(outputData);
    bytes.addAll('\nendstream'.codeUnits);
    return bytes;
  }
}
