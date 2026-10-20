import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'secure_messaging.dart';

/// Supported PACE protocols and curve parameters according to
/// ICAO Doc 9303 Part 11 & BSI TR-03110.
class PaceSecurityInfo {
  const PaceSecurityInfo({
    required this.oid,
    required this.oidBytes,
    required this.version,
    required this.parameterId,
    required this.isEcdh,
    required this.isAes,
    required this.keyLengthBytes,
    required this.curveName,
  });

  final String oid;
  final Uint8List oidBytes;
  final int version;
  final int? parameterId;
  final bool isEcdh;
  final bool isAes;
  final int keyLengthBytes;
  final String curveName;

  @override
  String toString() =>
      'PaceSecurityInfo(oid: $oid, ver: $version, paramId: $parameterId, curve: $curveName, keyLen: ${keyLengthBytes * 8})';
}

/// Helper and orchestrator for PACE (Password Authenticated Connection Establishment)
/// compliant with ICAO Doc 9303 Part 11.
class PaceCrypto {
  const PaceCrypto._();

  /// Known PACE OIDs
  static const String oidPrefixBsi = '0.4.0.127.0.7.2.2.4';
  static const String oidPrefixIcao = '0.4.0.127.0.0.3.2.4';

  /// Parses `EF.CardAccess` (ASN.1 SET OF SecurityInfo) and extracts the PACE configuration.
  static PaceSecurityInfo? parseCardAccess(Uint8List cardAccessBytes) {
    try {
      final parser = ASN1Parser(cardAccessBytes);
      if (!parser.hasNext()) return null;

      final top = parser.nextObject();
      List<ASN1Object> elements = [];
      if (top is ASN1Set && top.elements != null) {
        elements = top.elements!;
      } else if (top is ASN1Sequence && top.elements != null) {
        elements = top.elements!;
      } else {
        return null;
      }

      for (final elem in elements) {
        if (elem is! ASN1Sequence || elem.elements == null || elem.elements!.isEmpty) {
          continue;
        }

        final first = elem.elements![0];
        if (first is! ASN1ObjectIdentifier) continue;

        final oidStr = first.objectIdentifierAsString ?? '';
        if (oidStr.startsWith(oidPrefixBsi) || oidStr.startsWith(oidPrefixIcao)) {
          // Found PaceInfo!
          int version = 2;
          if (elem.elements!.length > 1 && elem.elements![1] is ASN1Integer) {
            version = (elem.elements![1] as ASN1Integer).integer?.toInt() ?? 2;
          }

          int? paramId;
          if (elem.elements!.length > 2 && elem.elements![2] is ASN1Integer) {
            paramId = (elem.elements![2] as ASN1Integer).integer?.toInt();
          }

          // Check if AES or 3DES
          final isAes = !oidStr.contains('3DES');
          final is256 = oidStr.endsWith('.4') || oidStr.endsWith('.256');
          final keyLen = is256 ? 32 : 16;

          // Resolve curve name from parameterId
          // 12 = NIST P-256 (secp256r1 / prime256v1)
          // 13 = BrainpoolP256r1
          // 15 = NIST P-384
          // 16 = BrainpoolP384r1
          String curveName = 'prime256v1';
          if (paramId == 13) {
            curveName = 'brainpoolp256r1';
          } else if (paramId == 15) {
            curveName = 'secp384r1';
          } else if (paramId == 16) {
            curveName = 'brainpoolp384r1';
          }

          final oidBytes = first.valueBytes ?? Uint8List(0);

          return PaceSecurityInfo(
            oid: oidStr,
            oidBytes: oidBytes,
            version: version,
            parameterId: paramId,
            isEcdh: true,
            isAes: isAes,
            keyLengthBytes: keyLen,
            curveName: curveName,
          );
        }
      }
    } catch (e) {
      debugPrint('[PACE] Failed to parse EF.CardAccess ASN.1: $e');
    }
    return null;
  }

  /// KDF for PACE session keys according to ICAO Doc 9303 Part 11:
  /// - mode = 1: Encryption Key (K_enc)
  /// - mode = 2: MAC Key (K_mac)
  /// - mode = 3: PACE Nonce Decryption Key (K_pi)
  static Uint8List derivePaceKey(Uint8List seed, int mode, {required int keyBytes}) {
    final counterBytes = Uint8List(4)..buffer.asByteData().setInt32(0, mode, Endian.big);
    final combined = Uint8List(seed.length + 4)
      ..setRange(0, seed.length, seed)
      ..setRange(seed.length, seed.length + 4, counterBytes);

    if (keyBytes > 16) {
      final digest = crypto.sha256.convert(combined);
      return Uint8List.fromList(digest.bytes.sublist(0, keyBytes));
    } else {
      final digest = crypto.sha1.convert(combined);
      return Uint8List.fromList(digest.bytes.sublist(0, keyBytes));
    }
  }

  /// Converts a BigInt coordinate to a fixed-length byte array with left-padding.
  static Uint8List bigIntToPaddedBytes(BigInt val, int len) {
    final hex = val.toRadixString(16).padLeft(len * 2, '0');
    final clean = hex.length > len * 2 ? hex.substring(hex.length - len * 2) : hex;
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Converts a byte array to BigInt (big-endian).
  static BigInt bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  /// Encrypts or decrypts using AES-CBC with explicit IV and NO padding.
  static Uint8List aesCbc(Uint8List key, Uint8List iv, Uint8List data, {required bool encrypt}) {
    final cbc = CBCBlockCipher(AESEngine())
      ..init(encrypt, ParametersWithIV(KeyParameter(key), iv));
    final out = Uint8List(data.length);
    for (int offset = 0; offset < data.length; offset += 16) {
      cbc.processBlock(data, offset, out, offset);
    }
    return out;
  }

  /// Encrypts a single 16-byte block using AES-ECB.
  static Uint8List aesEcbBlock(Uint8List key, Uint8List block16) {
    final ecb = ECBBlockCipher(AESEngine())..init(true, KeyParameter(key));
    final out = Uint8List(16);
    ecb.processBlock(block16, 0, out, 0);
    return out;
  }

  /// Computes RFC 4493 / NIST SP 800-38B AES-CMAC supporting both AES-128 and AES-256,
  /// truncated to [macBytes] (default: 8 bytes / 64 bits).
  static Uint8List computeAesCmac64(Uint8List key, Uint8List data, {int macBytes = 8}) {
    final ecb = ECBBlockCipher(AESEngine())..init(true, KeyParameter(key));

    Uint8List aesEncryptBlock(Uint8List block16) {
      final out = Uint8List(16);
      ecb.processBlock(block16, 0, out, 0);
      return out;
    }

    Uint8List shiftLeftOneBit(Uint8List input) {
      final output = Uint8List(16);
      int overflow = 0;
      for (int i = 15; i >= 0; i--) {
        final current = input[i];
        output[i] = ((current << 1) | overflow) & 0xFF;
        overflow = (current >> 7) & 1;
      }
      return output;
    }

    // Step 1: Generate Subkeys K1 and K2
    final zero16 = Uint8List(16);
    final l = aesEncryptBlock(zero16);

    var k1 = shiftLeftOneBit(l);
    if ((l[0] & 0x80) != 0) {
      k1[15] ^= 0x87;
    }

    var k2 = shiftLeftOneBit(k1);
    if ((k1[0] & 0x80) != 0) {
      k2[15] ^= 0x87;
    }

    // Step 2: Process message blocks
    final n = (data.isEmpty) ? 1 : (data.length + 15) ~/ 16;
    final flag = data.isNotEmpty && (data.length % 16 == 0);

    final mLast = Uint8List(16);
    if (flag) {
      final lastBlock = data.sublist((n - 1) * 16, n * 16);
      for (int i = 0; i < 16; i++) {
        mLast[i] = lastBlock[i] ^ k1[i];
      }
    } else {
      final offset = (n - 1) * 16;
      final remaining = data.length - offset;
      for (int i = 0; i < remaining; i++) {
        mLast[i] = data[offset + i];
      }
      mLast[remaining] = 0x80;
      for (int i = 0; i < 16; i++) {
        mLast[i] ^= k2[i];
      }
    }

    var x = Uint8List(16);
    final y = Uint8List(16);

    for (int i = 0; i < n - 1; i++) {
      for (int j = 0; j < 16; j++) {
        y[j] = x[j] ^ data[i * 16 + j];
      }
      x = aesEncryptBlock(y);
    }

    for (int j = 0; j < 16; j++) {
      y[j] = x[j] ^ mLast[j];
    }
    final t = aesEncryptBlock(y);

    return t.sublist(0, macBytes);
  }
}

/// State machine executing the PACE ECDH Generic Mapping handshake.
class PaceHandshake {
  PaceHandshake({
    required this.info,
    required this.passwordSeed,
    this.paceRef = 0x01, // 0x01 = MRZ password, 0x02 = CAN
  }) {
    _domainParams = ECDomainParameters(info.curveName);
    _coordLen = (_domainParams.curve.fieldSize + 7) ~/ 8;
  }

  final PaceSecurityInfo info;
  final String passwordSeed;
  final int paceRef;

  late final ECDomainParameters _domainParams;
  late final int _coordLen;

  // Ephemeral keys step 2
  late final ECPrivateKey _priv1;
  late final ECPublicKey _pub1;

  // Nonce
  late final BigInt _nonceBigInt;

  // Ephemeral keys step 3
  late final ECPrivateKey _priv2;
  late final ECPublicKey _pub2;

  // Session keys
  Uint8List? _ksEnc;
  Uint8List? _ksMac;

  Uint8List get ksEnc => _ksEnc!;
  Uint8List get ksMac => _ksMac!;

  /// Step 0: Generates `MSE:SET AT` APDU
  /// `00 22 C1 A4 [len] 80 [oidLen] [oidBytes] 83 01 [paceRef]`
  Uint8List buildSetAtApdu() {
    final builder = BytesBuilder()
      ..addByte(0x80)
      ..addByte(info.oidBytes.length)
      ..add(info.oidBytes)
      ..addByte(0x83)
      ..addByte(0x01)
      ..addByte(paceRef);

    final data = builder.toBytes();
    final apdu = BytesBuilder()
      ..add([0x00, 0x22, 0xC1, 0xA4, data.length])
      ..add(data);
    return apdu.toBytes();
  }

  /// Step 1: Generates `GENERAL AUTHENTICATE` APDU to get encrypted nonce
  /// `00 86 00 00 02 7C 00 00` (or `10 86 00 00 02 7C 00 00` with command chaining)
  Uint8List buildGetNonceApdu({bool useChaining = false}) {
    final cla = useChaining ? 0x10 : 0x00;
    return Uint8List.fromList([cla, 0x86, 0x00, 0x00, 0x02, 0x7C, 0x00, 0x00]);
  }

  /// Step 1: Decrypts the chip's encrypted nonce
  void processEncryptedNonce(Uint8List rapdu) {
    if (rapdu.length < 4) {
      throw const FormatException('Step 1 response too short');
    }
    // Expected TLV: 7C [len] 80 [len] [nonce (16 bytes)]
    final nonceEnc = _extractTag(rapdu, 0x80);
    if (nonceEnc == null || nonceEnc.isEmpty) {
      throw const FormatException('Step 1 response missing tag 0x80 (encrypted nonce)');
    }

    // In accordance with ICAO Doc 9303 Part 11 & BSI TR-03110 Section A.2.4:
    // Password encoding function f(pi):
    // For MRZ (length > 6): f(pi) = SHA-1(MRZ string) (20 bytes key seed).
    // For CAN (6 digits):   f(pi) = ASCII bytes of CAN.
    final Uint8List keySeed;
    if (passwordSeed.length > 6) {
      keySeed = Uint8List.fromList(crypto.sha1.convert(passwordSeed.codeUnits).bytes);
    } else {
      keySeed = Uint8List.fromList(passwordSeed.codeUnits);
    }
    final kPi = PaceCrypto.derivePaceKey(keySeed, 3, keyBytes: info.keyLengthBytes);

    // Decrypt nonce using AES-CBC with zero IV
    final zeroIv = Uint8List(16);
    final decryptedNonce = PaceCrypto.aesCbc(kPi, zeroIv, nonceEnc, encrypt: false);
    _nonceBigInt = PaceCrypto.bytesToBigInt(decryptedNonce);
    final nonceHex = decryptedNonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    debugPrint('[PACE] Nonce decrypted successfully (16 bytes): $nonceHex');
  }


  /// Step 2: Generates ephemeral keypair 1 and builds `GENERAL AUTHENTICATE` APDU
  Uint8List buildMapNonceApdu({bool useChaining = true}) {
    final random = Random.secure();
    final secRand = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => random.nextInt(256)))));

    final keyGen = KeyGenerator('EC')
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(_domainParams), secRand));
    final pair = keyGen.generateKeyPair();
    _priv1 = pair.privateKey as ECPrivateKey;
    _pub1 = pair.publicKey as ECPublicKey;

    final xBytes = PaceCrypto.bigIntToPaddedBytes(_pub1.Q!.x!.toBigInteger()!, _coordLen);
    final yBytes = PaceCrypto.bigIntToPaddedBytes(_pub1.Q!.y!.toBigInteger()!, _coordLen);

    // Dynamic Authentication Data: 7C [len] 81 [len] 04 [X1_x] [X1_y]
    final pointBytes = Uint8List(_coordLen * 2 + 1)
      ..[0] = 0x04
      ..setRange(1, 1 + _coordLen, xBytes)
      ..setRange(1 + _coordLen, 1 + _coordLen * 2, yBytes);

    final do81 = _buildTlv(0x81, pointBytes);
    final do7c = _buildTlv(0x7C, do81);

    final cla = useChaining ? 0x10 : 0x00;
    final apdu = BytesBuilder()
      ..add([cla, 0x86, 0x00, 0x00, do7c.length])
      ..add(do7c)
      ..addByte(0x00);
    return apdu.toBytes();
  }

  /// Step 2: Receives chip's mapping public key Y1 and maps the curve generator
  /// G~ = s * G + H1, then generates ephemeral keypair 2 (x2, X2) on G~
  Uint8List processChipMappingKeyAndBuildAgreementApdu(Uint8List rapdu, {bool useChaining = true}) {
    final chipPointBytes = _extractTag(rapdu, 0x82);
    if (chipPointBytes == null || chipPointBytes.length < 1 + _coordLen * 2) {
      throw const FormatException('Step 2 response missing tag 0x82 (chip mapping point)');
    }
    if (chipPointBytes[0] != 0x04) {
      throw const FormatException('Step 2 chip point is not uncompressed (0x04)');
    }

    final chipX = PaceCrypto.bytesToBigInt(chipPointBytes.sublist(1, 1 + _coordLen));
    final chipY = PaceCrypto.bytesToBigInt(chipPointBytes.sublist(1 + _coordLen, 1 + _coordLen * 2));
    final chipY1 = _domainParams.curve.createPoint(chipX, chipY);

    // Compute H1 = x1 * Y1
    final sharedSecretH1 = (chipY1 * _priv1.d!)!;

    // Compute mapped generator G~ = s * G + H1
    final sG = (_domainParams.G * _nonceBigInt)!;
    final mappedG = (sG + sharedSecretH1)!;

    debugPrint('[PACE] Curve generator mapped successfully to G~');

    // Create custom domain parameters with mapped generator
    final mappedParams = ECDomainParametersImpl(
      _domainParams.domainName,
      _domainParams.curve,
      mappedG,
      _domainParams.n,
    );

    // Generate ephemeral keypair 2 (x2, X2)
    final random = Random.secure();
    final secRand = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => random.nextInt(256)))));
    final keyGen2 = KeyGenerator('EC')
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(mappedParams), secRand));
    final pair2 = keyGen2.generateKeyPair();
    _priv2 = pair2.privateKey as ECPrivateKey;
    _pub2 = pair2.publicKey as ECPublicKey;

    final x2Bytes = PaceCrypto.bigIntToPaddedBytes(_pub2.Q!.x!.toBigInteger()!, _coordLen);
    final y2Bytes = PaceCrypto.bigIntToPaddedBytes(_pub2.Q!.y!.toBigInteger()!, _coordLen);

    // Dynamic Authentication Data: 7C [len] 83 [len] 04 [X2_x] [X2_y]
    final pointBytes = Uint8List(_coordLen * 2 + 1)
      ..[0] = 0x04
      ..setRange(1, 1 + _coordLen, x2Bytes)
      ..setRange(1 + _coordLen, 1 + _coordLen * 2, y2Bytes);

    final do83 = _buildTlv(0x83, pointBytes);
    final do7c = _buildTlv(0x7C, do83);

    final cla = useChaining ? 0x10 : 0x00;
    final apdu = BytesBuilder()
      ..add([cla, 0x86, 0x00, 0x00, do7c.length])
      ..add(do7c)
      ..addByte(0x00);
    return apdu.toBytes();
  }

  /// Step 3: Receives chip's ephemeral public key Y2, computes shared secret K = x2 * Y2,
  /// derives session keys KS_enc and KS_mac, and builds Step 4 Mutual Authentication APDU
  Uint8List processChipEphemeralKeyAndBuildTokenApdu(Uint8List rapdu) {
    final chipPointBytes = _extractTag(rapdu, 0x84);
    if (chipPointBytes == null || chipPointBytes.length < 1 + _coordLen * 2) {
      throw const FormatException('Step 3 response missing tag 0x84 (chip ephemeral point)');
    }
    if (chipPointBytes[0] != 0x04) {
      throw const FormatException('Step 3 chip point is not uncompressed (0x04)');
    }

    final chipX = PaceCrypto.bytesToBigInt(chipPointBytes.sublist(1, 1 + _coordLen));
    final chipY = PaceCrypto.bytesToBigInt(chipPointBytes.sublist(1 + _coordLen, 1 + _coordLen * 2));
    final chipY2 = _domainParams.curve.createPoint(chipX, chipY);

    // Shared secret K = x2 * Y2
    final sharedSecretK = (chipY2 * _priv2.d!)!;
    final kSeed = PaceCrypto.bigIntToPaddedBytes(sharedSecretK.x!.toBigInteger()!, _coordLen);

    // Derive session keys
    _ksEnc = PaceCrypto.derivePaceKey(kSeed, 1, keyBytes: info.keyLengthBytes);
    _ksMac = PaceCrypto.derivePaceKey(kSeed, 2, keyBytes: info.keyLengthBytes);

    debugPrint('[PACE] Derived session keys KS_enc and KS_mac');

    // Build Authentication Token T_IFD over chip's public key (DO84)
    // Input Data: 7F49 [len] 06 [oidLen] [oidBytes] 86 [keyLen] [04 || Y2]
    final oidTlv = _buildTlv(0x06, info.oidBytes);
    final keyTlv = _buildTlv(0x86, chipPointBytes);
    final inputBuilder = BytesBuilder()
      ..add(oidTlv)
      ..add(keyTlv);
    final do7f49 = _buildTlv2Bytes(0x7F49, inputBuilder.toBytes());

    final tIfd = PaceCrypto.computeAesCmac64(_ksMac!, do7f49);
    final tIfdHex = tIfd.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    debugPrint('[PACE] Step 4 T_IFD: $tIfdHex');

    // Build Step 4 APDU: 00 86 00 00 [len] 7C [len] 85 08 [T_IFD] 00

    final do85 = _buildTlv(0x85, tIfd);
    final do7c = _buildTlv(0x7C, do85);

    final apdu = BytesBuilder()
      ..add([0x00, 0x86, 0x00, 0x00, do7c.length])
      ..add(do7c)
      ..addByte(0x00);
    return apdu.toBytes();
  }

  /// Step 4: Verifies the chip's Authentication Token T_IC
  void verifyChipToken(Uint8List rapdu) {
    final tIc = _extractTag(rapdu, 0x86);
    if (tIc == null || tIc.length != 8) {
      throw const FormatException('Step 4 response missing tag 0x86 (chip auth token)');
    }

    // Build expected Token T_IC over terminal's public key (DO83)
    final x2Bytes = PaceCrypto.bigIntToPaddedBytes(_pub2.Q!.x!.toBigInteger()!, _coordLen);
    final y2Bytes = PaceCrypto.bigIntToPaddedBytes(_pub2.Q!.y!.toBigInteger()!, _coordLen);
    final terminalPointBytes = Uint8List(_coordLen * 2 + 1)
      ..[0] = 0x04
      ..setRange(1, 1 + _coordLen, x2Bytes)
      ..setRange(1 + _coordLen, 1 + _coordLen * 2, y2Bytes);

    final oidTlv = _buildTlv(0x06, info.oidBytes);
    final keyTlv = _buildTlv(0x86, terminalPointBytes);
    final inputBuilder = BytesBuilder()
      ..add(oidTlv)
      ..add(keyTlv);
    final do7f49 = _buildTlv2Bytes(0x7F49, inputBuilder.toBytes());

    final expectedTIc = PaceCrypto.computeAesCmac64(_ksMac!, do7f49);

    for (int i = 0; i < 8; i++) {
      if (tIc[i] != expectedTIc[i]) {
        throw const FormatException('Chip authentication token verification failed (T_IC mismatch)');
      }
    }
    debugPrint('[PACE] ✅ Mutual authentication token verified with chip!');
  }

  /// Creates initialized SecureMessaging instance ready for Data Group reading
  SecureMessaging createSecureMessaging() {
    return SecureMessaging.aes(
      ksEnc: _ksEnc!,
      ksMac: _ksMac!,
    );
  }

  static Uint8List _buildTlv(int tag, Uint8List val) {
    final b = BytesBuilder()..addByte(tag);
    if (val.length < 128) {
      b.addByte(val.length);
    } else if (val.length <= 255) {
      b.addByte(0x81);
      b.addByte(val.length);
    } else {
      b.addByte(0x82);
      b.addByte((val.length >> 8) & 0xFF);
      b.addByte(val.length & 0xFF);
    }
    b.add(val);
    return b.toBytes();
  }

  static Uint8List _buildTlv2Bytes(int tag2Bytes, Uint8List val) {
    final b = BytesBuilder()
      ..addByte((tag2Bytes >> 8) & 0xFF)
      ..addByte(tag2Bytes & 0xFF);
    if (val.length < 128) {
      b.addByte(val.length);
    } else if (val.length <= 255) {
      b.addByte(0x81);
      b.addByte(val.length);
    } else {
      b.addByte(0x82);
      b.addByte((val.length >> 8) & 0xFF);
      b.addByte(val.length & 0xFF);
    }
    b.add(val);
    return b.toBytes();
  }

  static Uint8List? _extractTag(Uint8List data, int targetTag) {
    int i = 0;
    while (i < data.length) {
      // Check for 7C container
      int tag = data[i++];
      if (tag == 0x7C) {
        // Skip length
        if (i >= data.length) break;
        int len = data[i++];
        if (len == 0x81 && i < data.length) {
          len = data[i++];
        } else if (len == 0x82 && i + 1 < data.length) {
          len = (data[i++] << 8) | data[i++];
        }
        continue;
      }

      int len = (i < data.length) ? data[i++] : 0;
      if (len == 0x81 && i < data.length) {
        len = data[i++];
      } else if (len == 0x82 && i + 1 < data.length) {
        len = (data[i++] << 8) | data[i++];
      }

      if (tag == targetTag && i + len <= data.length) {
        return data.sublist(i, i + len);
      }
      i += len;
    }
    return null;
  }
}
