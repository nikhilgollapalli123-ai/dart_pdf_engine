/// Tracks byte offsets of indirect objects for the cross-reference table.
class PdfCrossReference {
  final List<_XRefEntry> _entries = [];

  /// Record an object's byte offset.
  void addEntry(int objectNumber, int byteOffset,
      [int generationNumber = 0, bool inUse = true]) {
    _entries.add(_XRefEntry(objectNumber, byteOffset, generationNumber, inUse));
  }

  /// Write the xref table and return its byte offset.
  List<int> toBytes() {
    // Sort by object number.
    _entries.sort((a, b) => a.objectNumber.compareTo(b.objectNumber));

    final buffer = StringBuffer();
    buffer.write('xref\n');

    if (_entries.isEmpty) {
      buffer.write('0 1\n');
      buffer.write('0000000000 65535 f \n');
    } else {
      // Always include the free entry at object 0.
      final allEntries = <_XRefEntry>[
        _XRefEntry(0, 0, 65535, false),
        ..._entries,
      ];

      int rangeStart = allEntries.first.objectNumber;
      List<_XRefEntry> currentRange = [allEntries.first];

      for (int i = 1; i < allEntries.length; i++) {
        if (allEntries[i].objectNumber ==
            allEntries[i - 1].objectNumber + 1) {
          currentRange.add(allEntries[i]);
        } else {
          // Write current range.
          _writeRange(buffer, rangeStart, currentRange);
          rangeStart = allEntries[i].objectNumber;
          currentRange = [allEntries[i]];
        }
      }
      // Write last range.
      _writeRange(buffer, rangeStart, currentRange);
    }

    return buffer.toString().codeUnits;
  }

  void _writeRange(
      StringBuffer buffer, int startObj, List<_XRefEntry> entries) {
    buffer.write('$startObj ${entries.length}\n');
    for (final entry in entries) {
      final offset =
          entry.byteOffset.toString().padLeft(10, '0');
      final gen =
          entry.generationNumber.toString().padLeft(5, '0');
      final flag = entry.inUse ? 'n' : 'f';
      buffer.write('$offset $gen $flag \n');
    }
  }
}

class _XRefEntry {
  final int objectNumber;
  final int byteOffset;
  final int generationNumber;
  final bool inUse;

  _XRefEntry(
      this.objectNumber, this.byteOffset, this.generationNumber, this.inUse);
}
