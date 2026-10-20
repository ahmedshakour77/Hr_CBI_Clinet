import 'dart:convert';
import 'dart:typed_data';

/// ASN.1 / ISO 7816-4 BER-TLV node
class TlvNode {
  const TlvNode({
    required this.tag,
    required this.length,
    required this.value,
  });

  final int tag;
  final int length;
  final Uint8List value;

  bool get isConstructed => (tag & 0x20) != 0;

  @override
  String toString() => 'TlvNode(tag: 0x${tag.toRadixString(16).toUpperCase()}, len: $length)';
}

/// Robust BER-TLV Parser & Biometric Image Extractor
class TlvParser {
  const TlvParser._();

  /// Parses a raw byte buffer into a list of top-level [TlvNode]s.
  static List<TlvNode> parse(Uint8List buffer) {
    final nodes = <TlvNode>[];
    int offset = 0;

    while (offset < buffer.length) {
      if (buffer[offset] == 0x00 || buffer[offset] == 0xFF) {
        // Skip padding bytes
        offset++;
        continue;
      }

      // 1. Parse Tag (supports 1 or 2 byte tags)
      int tag = buffer[offset++];
      if ((tag & 0x1F) == 0x1F && offset < buffer.length) {
        // Multi-byte tag (e.g. 0x5F1F, 0x7F61)
        tag = (tag << 8) | buffer[offset++];
      }

      if (offset >= buffer.length) break;

      // 2. Parse Length
      int len = buffer[offset++];
      if (len == 0x81) {
        if (offset >= buffer.length) break;
        len = buffer[offset++];
      } else if (len == 0x82) {
        if (offset + 1 >= buffer.length) break;
        len = (buffer[offset] << 8) | buffer[offset + 1];
        offset += 2;
      } else if (len == 0x83) {
        if (offset + 2 >= buffer.length) break;
        len = (buffer[offset] << 16) | (buffer[offset + 1] << 8) | buffer[offset + 2];
        offset += 3;
      } else if (len > 0x83) {
        // Indefinite or unsupported length format
        break;
      }

      if (offset + len > buffer.length) {
        // Truncated buffer: consume remaining bytes
        nodes.add(TlvNode(tag: tag, length: buffer.length - offset, value: buffer.sublist(offset)));
        break;
      }

      final val = buffer.sublist(offset, offset + len);
      nodes.add(TlvNode(tag: tag, length: len, value: val));
      offset += len;
    }

    return nodes;
  }

  /// Searches recursively for a given tag (e.g., 0x5F1F for MRZ or 0x5F2E for Facial Record).
  static Uint8List? findTag(Uint8List buffer, int targetTag) {
    final nodes = parse(buffer);
    for (final node in nodes) {
      if (node.tag == targetTag) {
        return node.value;
      }
      if (node.isConstructed) {
        final sub = findTag(node.value, targetTag);
        if (sub != null) return sub;
      }
    }
    return null;
  }

  /// Extracts biometric portrait image bytes from Data Group 2 (DG2).
  /// DG2 conforms to ISO/IEC 19794-5 (Biometric data interchange formats - Face).
  /// This scanner locates the standard graphic codestreams (JPEG / JPEG2000)
  /// embedded within the Biometric Data Block (BDB).
  static Uint8List? extractFacialImage(Uint8List dg2Bytes) {
    if (dg2Bytes.length < 10) return null;

    // Pattern 1: JPEG (SOI marker 0xFF 0xD8 0xFF)
    for (int i = 0; i < dg2Bytes.length - 4; i++) {
      if (dg2Bytes[i] == 0xFF &&
          dg2Bytes[i + 1] == 0xD8 &&
          dg2Bytes[i + 2] == 0xFF) {
        // Found JPEG Start of Image (SOI). Search for EOI (0xFF 0xD9)
        int end = dg2Bytes.length;
        for (int j = i + 3; j < dg2Bytes.length - 1; j++) {
          if (dg2Bytes[j] == 0xFF && dg2Bytes[j + 1] == 0xD9) {
            end = j + 2;
            break;
          }
        }
        return dg2Bytes.sublist(i, end);
      }
    }

    // Pattern 2: JPEG 2000 with JP2 File Format signature:
    // 0x00 0x00 0x00 0x0C 0x6A 0x50 0x20 0x20 (magic box)
    for (int i = 0; i < dg2Bytes.length - 12; i++) {
      if (dg2Bytes[i] == 0x00 &&
          dg2Bytes[i + 1] == 0x00 &&
          dg2Bytes[i + 2] == 0x00 &&
          dg2Bytes[i + 3] == 0x0C &&
          dg2Bytes[i + 4] == 0x6A &&
          dg2Bytes[i + 5] == 0x50 &&
          dg2Bytes[i + 6] == 0x20 &&
          dg2Bytes[i + 7] == 0x20) {
        return dg2Bytes.sublist(i);
      }
    }

    // Pattern 3: JPEG 2000 Raw Codestream: 0xFF 0x4F 0xFF 0x51 (SOC / SIZ marker)
    for (int i = 0; i < dg2Bytes.length - 4; i++) {
      if (dg2Bytes[i] == 0xFF &&
          dg2Bytes[i + 1] == 0x4F &&
          dg2Bytes[i + 2] == 0xFF &&
          dg2Bytes[i + 3] == 0x51) {
        return dg2Bytes.sublist(i);
      }
    }

    return null;
  }

  /// Decodes a UTF-8 text string from a specified BER-TLV tag,
  /// converting ICAO chevron separators '<' into clean spaces.
  static String? parseString(Uint8List buffer, int targetTag) {
    final raw = findTag(buffer, targetTag);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = utf8.decode(raw, allowMalformed: true);
      final clean = decoded.replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return clean.isNotEmpty ? clean : null;
    } catch (_) {
      return null;
    }
  }

  /// Decodes an ISO / ICAO date string (e.g., YYYYMMDD or YYMMDD) from a tag.
  static DateTime? parseDate(Uint8List buffer, int targetTag) {
    final raw = findTag(buffer, targetTag);
    if (raw == null || raw.isEmpty) return null;
    try {
      final str = utf8.decode(raw, allowMalformed: true).replaceAll(RegExp(r'[^0-9]'), '');
      if (str.length == 8) {
        final year = int.parse(str.substring(0, 4));
        final month = int.parse(str.substring(4, 6));
        final day = int.parse(str.substring(6, 8));
        return DateTime(year, month, day);
      } else if (str.length == 6) {
        int year = int.parse(str.substring(0, 2));
        final month = int.parse(str.substring(2, 4));
        final day = int.parse(str.substring(4, 6));
        final currentYearTwoDigits = DateTime.now().year % 100;
        year += (year <= currentYearTwoDigits + 10) ? 2000 : 1900;
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  /// Parses EF.COM tag 0x5C (Tag List) to discover available Data Groups on the chip.
  static List<int> parsePresentDgs(Uint8List comBytes) {
    final list = <int>[];
    final tagListData = findTag(comBytes, 0x5C);
    if (tagListData == null) return list;

    for (final tag in tagListData) {
      switch (tag) {
        case 0x61: list.add(1); break;
        case 0x75: list.add(2); break;
        case 0x63: list.add(3); break;
        case 0x76: list.add(4); break;
        case 0x65: list.add(5); break;
        case 0x66: list.add(6); break;
        case 0x67: list.add(7); break;
        case 0x68: list.add(8); break;
        case 0x69: list.add(9); break;
        case 0x6A: list.add(10); break;
        case 0x6B: list.add(11); break;
        case 0x6C: list.add(12); break;
        case 0x6D: list.add(13); break;
        case 0x6E: list.add(14); break;
        case 0x6F: list.add(15); break;
        case 0x70: list.add(16); break;
      }
    }
    return list;
  }

  /// Extracts signature / mark graphic from Data Group 7 (DG7).
  static Uint8List? extractSignatureImage(Uint8List dg7Bytes) {
    return extractFacialImage(dg7Bytes);
  }
}

