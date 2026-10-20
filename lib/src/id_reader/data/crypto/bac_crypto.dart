import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

/// Cryptographic primitives for ICAO Doc 9303 Part 11:
/// - Basic Access Control (BAC) Key Derivation
/// - 2-Key 3DES CBC / ECB operations
/// - ISO/IEC 9797-1 MAC Algorithm 3 (Retail MAC)
/// - ISO/IEC 7816-4 Padding
class BacCrypto {
  const BacCrypto._();

  /// Derives K_seed (first 16 bytes of SHA-1) from the 24-character MRZ seed string.
  /// Example: DocumentNumber(9) + CheckDigit(1) + DOB(6) + CheckDigit(1) + DOE(6) + CheckDigit(1).
  static Uint8List deriveKeySeed(String mrzSeed) {
    final bytes = utf8.encode(mrzSeed);
    final digest = crypto.sha1.convert(bytes);
    return Uint8List.fromList(digest.bytes.sublist(0, 16));
  }

  /// Derives a 16-byte DES key from K_seed according to ICAO 9303 Part 11:
  /// - [counter] = 1 for Encryption Key (K_enc)
  /// - [counter] = 2 for MAC Key (K_mac)
  static Uint8List deriveKey(Uint8List kSeed, int counter) {
    final counterBytes = Uint8List.fromList([0x00, 0x00, 0x00, counter]);
    final combined = Uint8List(kSeed.length + counterBytes.length)
      ..setRange(0, kSeed.length, kSeed)
      ..setRange(kSeed.length, kSeed.length + counterBytes.length, counterBytes);

    final digest = crypto.sha1.convert(combined);
    final keyBytes = Uint8List.fromList(digest.bytes.sublist(0, 16));
    return adjustParity(keyBytes);
  }

  /// Adjusts each byte in the key to odd parity (FIPS 46-3 requirement for DES keys).
  static Uint8List adjustParity(Uint8List key) {
    final adjusted = Uint8List(key.length);
    for (int i = 0; i < key.length; i++) {
      int b = key[i];
      int bitCount = 0;
      for (int bit = 1; bit < 8; bit++) {
        if ((b & (1 << bit)) != 0) bitCount++;
      }
      if (bitCount % 2 == 0) {
        adjusted[i] = (b & 0xFE) | 1;
      } else {
        adjusted[i] = (b & 0xFE);
      }
    }
    return adjusted;
  }

  /// Converts a 16-byte 2-Key Triple DES key into the 24-byte format expected
  /// by DESedeEngine (Ka || Kb || Ka).
  static Uint8List expandKeyTo24(Uint8List key16) {
    if (key16.length == 24) return key16;
    if (key16.length != 16) {
      throw ArgumentError('Expected 16-byte key for 2-Key 3DES, got ${key16.length}');
    }
    final expanded = Uint8List(24);
    expanded.setRange(0, 16, key16);
    expanded.setRange(16, 24, key16.sublist(0, 8)); // K3 = K1
    return expanded;
  }

  /// Performs 2-Key 3DES encryption in CBC mode with an explicit 8-byte IV.
  static Uint8List des3CbcEncrypt(Uint8List key16, Uint8List iv8, Uint8List data) {
    if (data.length % 8 != 0) {
      throw ArgumentError('Data length must be a multiple of 8, got ${data.length}');
    }
    final key24 = expandKeyTo24(key16);
    final cbc = CBCBlockCipher(DESedeEngine())
      ..init(true, ParametersWithIV(KeyParameter(key24), iv8));

    final out = Uint8List(data.length);
    for (int offset = 0; offset < data.length; offset += 8) {
      cbc.processBlock(data, offset, out, offset);
    }
    return out;
  }

  /// Performs 2-Key 3DES decryption in CBC mode with an explicit 8-byte IV.
  static Uint8List des3CbcDecrypt(Uint8List key16, Uint8List iv8, Uint8List data) {
    if (data.length % 8 != 0) {
      throw ArgumentError('Ciphertext length must be a multiple of 8, got ${data.length}');
    }
    final key24 = expandKeyTo24(key16);
    final cbc = CBCBlockCipher(DESedeEngine())
      ..init(false, ParametersWithIV(KeyParameter(key24), iv8));

    final out = Uint8List(data.length);
    for (int offset = 0; offset < data.length; offset += 8) {
      cbc.processBlock(data, offset, out, offset);
    }
    return out;
  }

  /// Encrypts a single 8-byte block using 2-Key 3DES in ECB mode.
  /// Used in Secure Messaging to calculate dynamic IV from SSC: IV = 3DES_ECB(KS_enc, SSC).
  static Uint8List des3EcbEncrypt(Uint8List key16, Uint8List block8) {
    if (block8.length != 8) {
      throw ArgumentError('Block length must be 8 bytes, got ${block8.length}');
    }
    final key24 = expandKeyTo24(key16);
    final engine = DESedeEngine()..init(true, KeyParameter(key24));
    final out = Uint8List(8);
    engine.processBlock(block8, 0, out, 0);
    return out;
  }

  /// Computes ISO/IEC 9797-1 MAC Algorithm 3 (Retail MAC) with ISO 7816-4 padding.
  /// Key: 16 bytes (Ka = key[0..8], Kb = key[8..16]).
  /// Process:
  /// - Pad data with ISO 7816-4 (0x80 followed by 0x00s to multiple of 8)
  /// - Forward CBC pass using single DES with Ka (Ka || Ka || Ka in EDE)
  /// - Final block: 2-key 3DES EDE with Ka || Kb || Ka
  static Uint8List iso9797MacAlg3(Uint8List key16, Uint8List unpaddedData) {
    if (key16.length != 16) {
      throw ArgumentError('MAC key must be 16 bytes, got ${key16.length}');
    }

    final padded = padIso7816(unpaddedData, 8);
    final ka = key16.sublist(0, 8);
    final kb = key16.sublist(8, 16);

    // Single DES Ka equivalent via 3DES: Ka || Ka || Ka
    final ka24 = Uint8List(24)
      ..setRange(0, 8, ka)
      ..setRange(8, 16, ka)
      ..setRange(16, 24, ka);

    // Final 2-Key 3DES block key: Ka || Kb || Ka
    final kab24 = Uint8List(24)
      ..setRange(0, 8, ka)
      ..setRange(8, 16, kb)
      ..setRange(16, 24, ka);

    final desKaEnc = DESedeEngine()..init(true, KeyParameter(ka24));
    final desFinalEnc = DESedeEngine()..init(true, KeyParameter(kab24));

    Uint8List block = Uint8List(8); // IV = 0
    final numBlocks = padded.length ~/ 8;

    // Intermediate blocks 1 .. N-1: single DES with Ka
    for (int b = 0; b < numBlocks - 1; b++) {
      final offset = b * 8;
      for (int i = 0; i < 8; i++) {
        block[i] ^= padded[offset + i];
      }
      final nextBlock = Uint8List(8);
      desKaEnc.processBlock(block, 0, nextBlock, 0);
      block = nextBlock;
    }

    // Final block N: XOR with previous block, then 3DES-EDE with (Ka, Kb, Ka)
    final lastOffset = (numBlocks - 1) * 8;
    for (int i = 0; i < 8; i++) {
      block[i] ^= padded[lastOffset + i];
    }
    final mac = Uint8List(8);
    desFinalEnc.processBlock(block, 0, mac, 0);

    return mac;
  }

  /// Appends ISO/IEC 7816-4 padding: single 0x80 byte, followed by 0x00 bytes
  /// to make total length a multiple of [blockSize].
  static Uint8List padIso7816(Uint8List data, int blockSize) {
    final remainder = data.length % blockSize;
    final paddingLength = blockSize - remainder;
    final padded = Uint8List(data.length + paddingLength);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;
    // Remainder initialized to 0x00 by default Uint8List constructor
    return padded;
  }

  /// Removes ISO/IEC 7816-4 padding from decrypted plaintext.
  static Uint8List unpadIso7816(Uint8List paddedData) {
    int index = paddedData.length - 1;
    while (index >= 0 && paddedData[index] == 0x00) {
      index--;
    }
    if (index < 0 || paddedData[index] != 0x80) {
      throw const FormatException('Invalid ISO 7816-4 padding encountered.');
    }
    return Uint8List.fromList(paddedData.sublist(0, index));
  }
}
