import 'dart:typed_data';
import 'bac_crypto.dart';
import 'pace_crypto.dart';

enum SmCipherType {
  des3,
  aes,
}

/// Implements ISO/IEC 7816-4 Secure Messaging (SM) compliant with
/// ICAO Doc 9303 Part 11 for both:
/// - Basic Access Control (BAC): 2-Key 3DES CBC + ISO 9797 MAC Alg 3
/// - Password Authenticated Connection Establishment (PACE): AES-128/256 CBC + AES-CMAC
class SecureMessaging {
  SecureMessaging({
    required this.ksEnc,
    required this.ksMac,
    required Uint8List initialSsc,
    this.type = SmCipherType.des3,
  }) {
    if (type == SmCipherType.des3) {
      if (ksEnc.length != 16 || ksMac.length != 16) {
        throw ArgumentError('3DES session keys KS_enc and KS_mac must both be 16 bytes.');
      }
      if (initialSsc.length != 8) {
        throw ArgumentError('Initial 3DES SSC must be exactly 8 bytes.');
      }
    } else {
      if (initialSsc.length != 16) {
        throw ArgumentError('Initial AES SSC must be exactly 16 bytes.');
      }
    }
    _ssc = _bytesToBigInt(initialSsc);
  }

  /// Factory constructor for AES Secure Messaging (PACE)
  factory SecureMessaging.aes({
    required Uint8List ksEnc,
    required Uint8List ksMac,
  }) {
    return SecureMessaging(
      ksEnc: ksEnc,
      ksMac: ksMac,
      initialSsc: Uint8List(16), // PACE starts with 16-byte zero SSC
      type: SmCipherType.aes,
    );
  }

  final Uint8List ksEnc;
  final Uint8List ksMac;
  final SmCipherType type;
  late BigInt _ssc;

  /// Current Send Sequence Counter (SSC) value
  BigInt get ssc => _ssc;

  /// Increments the SSC modulo 2^64 (3DES) or 2^128 (AES)
  void _incrementSsc() {
    if (type == SmCipherType.des3) {
      _ssc = (_ssc + BigInt.one) & BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);
    } else {
      _ssc = (_ssc + BigInt.one) &
          BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', radix: 16);
    }
  }

  /// Converts the current SSC to a big-endian byte array (8 bytes for 3DES, 16 for AES)
  Uint8List _sscToBytes() {
    final len = type == SmCipherType.des3 ? 8 : 16;
    final bytes = Uint8List(len);
    var temp = _ssc;
    for (int i = len - 1; i >= 0; i--) {
      bytes[i] = (temp & BigInt.from(0xFF)).toInt();
      temp = temp >> 8;
    }
    return bytes;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  /// Wraps an unprotected command APDU into a Secure Messaging protected APDU:
  /// - Sets SM bits in CLA (0x0C)
  /// - Encrypts command data into DO87
  /// - Encodes expected response length into DO97
  /// - Appends MAC checksum in DO8E
  Uint8List wrapCommand(Uint8List header, {Uint8List? data, int? le}) {
    if (header.length != 4) {
      throw ArgumentError('APDU header must be exactly 4 bytes (CLA INS P1 P2).');
    }

    // Step 1: Increment SSC before command transmission
    _incrementSsc();
    final sscBytes = _sscToBytes();

    // Step 2: Build DO87 if command has payload
    Uint8List do87 = Uint8List(0);
    if (data != null && data.isNotEmpty) {
      final blockSize = type == SmCipherType.des3 ? 8 : 16;
      final paddedData = BacCrypto.padIso7816(data, blockSize);

      Uint8List cipher;
      if (type == SmCipherType.des3) {
        // In 3DES BAC (ICAO Doc 9303 Part 11), IV is a fixed 8-byte zero vector
        final zeroIv = Uint8List(8);
        cipher = BacCrypto.des3CbcEncrypt(ksEnc, zeroIv, paddedData);
      } else {
        // In AES PACE (ICAO Doc 9303 Part 11), IV = AES_ECB(KS_enc, SSC)
        final iv = PaceCrypto.aesEcbBlock(ksEnc, sscBytes);
        cipher = PaceCrypto.aesCbc(ksEnc, iv, paddedData, encrypt: true);
      }

      // Value = [0x01 (padding indicator)] + cipher
      final do87Val = Uint8List(1 + cipher.length);
      do87Val[0] = 0x01;
      do87Val.setRange(1, do87Val.length, cipher);

      do87 = _buildTlv(0x87, do87Val);
    }

    // Step 3: Build DO97 if Le is specified
    Uint8List do97 = Uint8List(0);
    if (le != null) {
      do97 = _buildTlv(0x97, Uint8List.fromList([le]));
    }

    // Step 4: Compute MAC over (SSC || Header_masked || DO87 || DO97)
    final maskedCla = header[0] | 0x0C;
    final maskedHeaderLength = type == SmCipherType.des3 ? 8 : 16;
    final maskedHeader = Uint8List(maskedHeaderLength);
    maskedHeader[0] = maskedCla;
    maskedHeader[1] = header[1];
    maskedHeader[2] = header[2];
    maskedHeader[3] = header[3];
    maskedHeader[4] = 0x80; // ISO 7816-4 header padding

    final macInput = BytesBuilder()
      ..add(sscBytes)
      ..add(maskedHeader)
      ..add(do87)
      ..add(do97);

    final unpaddedInput = macInput.toBytes();
    Uint8List mac;
    if (type == SmCipherType.des3) {
      mac = BacCrypto.iso9797MacAlg3(ksMac, unpaddedInput);
    } else {
      final paddedInput = BacCrypto.padIso7816(unpaddedInput, 16);
      mac = PaceCrypto.computeAesCmac64(ksMac, paddedInput);
    }
    final do8e = _buildTlv(0x8E, mac);

    // Step 5: Assemble protected APDU
    final smPayload = BytesBuilder()
      ..add(do87)
      ..add(do97)
      ..add(do8e);
    final payloadBytes = smPayload.toBytes();

    final protectedApdu = BytesBuilder()
      ..addByte(maskedCla)
      ..addByte(header[1])
      ..addByte(header[2])
      ..addByte(header[3])
      ..addByte(payloadBytes.length)
      ..add(payloadBytes)
      ..addByte(0x00); // Le = 0x00 required in SM

    return protectedApdu.toBytes();
  }

  /// Unwraps and verifies an APDU response returned under Secure Messaging:
  /// - Increments SSC
  /// - Verifies response MAC (DO8E)
  /// - Decrypts payload (DO87) if present
  /// - Extracts status word (SW1, SW2) from DO99
  UnwrappedResponse unwrapResponse(Uint8List response) {
    if (response.length < 2) {
      throw const FormatException('APDU response too short.');
    }

    // Status word at the tail of raw response (usually 90 00)
    final sw1 = response[response.length - 2];
    final sw2 = response[response.length - 1];

    if (sw1 != 0x90 && sw1 != 0x61 && sw1 != 0x99) {
      return UnwrappedResponse(
        data: Uint8List(0),
        sw1: sw1,
        sw2: sw2,
        isSuccess: false,
      );
    }

    // Parse TLVs in response body (excluding trailing SW1 SW2)
    final body = response.sublist(0, response.length - 2);
    if (body.isEmpty) {
      return UnwrappedResponse(
        data: Uint8List(0),
        sw1: sw1,
        sw2: sw2,
        isSuccess: sw1 == 0x90 && sw2 == 0x00,
      );
    }

    // Increment SSC for the response (only when body contains SM data objects)
    _incrementSsc();
    final sscBytes = _sscToBytes();

    final tlvs = _parseSimpleTlvs(body);

    final do87 = tlvs[0x87];
    final do99 = tlvs[0x99];
    final do8e = tlvs[0x8E];

    if (do99 == null || do8e == null) {
      return UnwrappedResponse(
        data: Uint8List(0),
        sw1: sw1,
        sw2: sw2,
        isSuccess: false,
      );
    }

    // Verify MAC over (SSC || DO87 (or DO85) || DO99)
    final macInput = BytesBuilder()..add(sscBytes);
    if (do87 != null) {
      macInput.add(_buildTlv(0x87, do87));
    } else if (tlvs[0x85] != null) {
      macInput.add(_buildTlv(0x85, tlvs[0x85]!));
    }
    macInput.add(_buildTlv(0x99, do99));

    final unpaddedRespInput = macInput.toBytes();
    Uint8List expectedMac;
    if (type == SmCipherType.des3) {
      expectedMac = BacCrypto.iso9797MacAlg3(ksMac, unpaddedRespInput);
    } else {
      final paddedRespInput = BacCrypto.padIso7816(unpaddedRespInput, 16);
      expectedMac = PaceCrypto.computeAesCmac64(ksMac, paddedRespInput);
    }

    if (!_constantTimeEquals(expectedMac, do8e)) {
      throw const FormatException('Secure Messaging MAC verification failed! Potential tampering.');
    }

    // Decrypt data group payload if present (DO87 or DO85)
    Uint8List plainData = Uint8List(0);
    if (do87 != null && do87.length > 1) {
      // First byte of DO87 value is padding indicator (0x01)
      final ciphertext = do87.sublist(1);
      if (type == SmCipherType.des3) {
        final zeroIv = Uint8List(8);
        final decrypted = BacCrypto.des3CbcDecrypt(ksEnc, zeroIv, ciphertext);
        plainData = BacCrypto.unpadIso7816(decrypted);
      } else {
        final iv = PaceCrypto.aesEcbBlock(ksEnc, sscBytes);
        final decrypted = PaceCrypto.aesCbc(ksEnc, iv, ciphertext, encrypt: false);
        plainData = BacCrypto.unpadIso7816(decrypted);
      }
    } else if (tlvs[0x85] != null && tlvs[0x85]!.isNotEmpty) {
      final ciphertext = tlvs[0x85]!;
      if (type == SmCipherType.des3) {
        final zeroIv = Uint8List(8);
        final decrypted = BacCrypto.des3CbcDecrypt(ksEnc, zeroIv, ciphertext);
        plainData = BacCrypto.unpadIso7816(decrypted);
      } else {
        final iv = PaceCrypto.aesEcbBlock(ksEnc, sscBytes);
        final decrypted = PaceCrypto.aesCbc(ksEnc, iv, ciphertext, encrypt: false);
        plainData = BacCrypto.unpadIso7816(decrypted);
      }
    }

    final respSw1 = do99[0];
    final respSw2 = do99[1];

    return UnwrappedResponse(
      data: plainData,
      sw1: respSw1,
      sw2: respSw2,
      isSuccess: respSw1 == 0x90 && respSw2 == 0x00,
    );
  }

  static Uint8List _buildTlv(int tag, Uint8List value) {
    final builder = BytesBuilder();
    builder.addByte(tag);
    if (value.length < 0x80) {
      builder.addByte(value.length);
    } else if (value.length <= 0xFF) {
      builder.addByte(0x81);
      builder.addByte(value.length);
    } else {
      builder.addByte(0x82);
      builder.addByte((value.length >> 8) & 0xFF);
      builder.addByte(value.length & 0xFF);
    }
    builder.add(value);
    return builder.toBytes();
  }

  static Map<int, Uint8List> _parseSimpleTlvs(Uint8List buffer) {
    final map = <int, Uint8List>{};
    int offset = 0;
    while (offset < buffer.length) {
      final tag = buffer[offset++];
      if (offset >= buffer.length) break;
      int len = buffer[offset++];
      if (len == 0x81) {
        if (offset >= buffer.length) break;
        len = buffer[offset++];
      } else if (len == 0x82) {
        if (offset + 1 >= buffer.length) break;
        len = (buffer[offset] << 8) | buffer[offset + 1];
        offset += 2;
      }
      if (offset + len > buffer.length) break;
      map[tag] = buffer.sublist(offset, offset + len);
      offset += len;
    }
    return map;
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

class UnwrappedResponse {
  const UnwrappedResponse({
    required this.data,
    required this.sw1,
    required this.sw2,
    required this.isSuccess,
  });

  final Uint8List data;
  final int sw1;
  final int sw2;
  final bool isSuccess;
}
