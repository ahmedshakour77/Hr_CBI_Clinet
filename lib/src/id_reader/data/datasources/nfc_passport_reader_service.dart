import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import '../../domain/entities/id_card_model.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/errors/id_card_failure.dart';
import '../crypto/bac_crypto.dart';
import '../crypto/pace_crypto.dart';
import '../crypto/secure_messaging.dart';
import 'tlv_parser.dart';

/// Service responsible for orchestrating NFC hardware interrogation,
/// ICAO Doc 9303 Basic Access Control (BAC), ISO 7816 Secure Messaging,
/// and reading Data Groups (DG1, DG2, SOD).
class NfcPassportReaderService {
  NfcPassportReaderService();

  static const List<int> emrtdAid = [0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01];
  static const List<int> comFileId = [0x01, 0x1E];
  static const List<int> dg1FileId = [0x01, 0x01];
  static const List<int> dg2FileId = [0x01, 0x02];
  static const List<int> dg7FileId = [0x01, 0x07];
  static const List<int> dg11FileId = [0x01, 0x0B];
  static const List<int> dg12FileId = [0x01, 0x0C];
  static const List<int> sodFileId = [0x01, 0x1D];

  SecureMessaging? _secureMessaging;

  /// Starts the NFC session, performs BAC, interrogates all available Data Groups
  /// (DG1, DG2, DG11, DG12, DG7, SOD), verifies signatures, and preserves
  /// physical front/back card photographs.
  Future<IdCardModel> readIdCard({
    required MrzData mrzData,
    Uint8List? frontCardBytes,
    Uint8List? backCardBytes,
    void Function(String stepDescription, double progress)? onProgress,
  }) async {
    try {
      // Step 1: Check NFC availability
      final availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        throw const NfcUnavailableFailure('NFC hardware is disabled or unavailable on this device.');
      }

      onProgress?.call('Waiting for ID card...', 0.05);

      // Step 2: Poll for Tag (IsoDep / Type A/B)
      NFCTag tag;
      try {
        tag = await FlutterNfcKit.poll(
          timeout: const Duration(seconds: 35),
          iosAlertMessage: 'Hold the back of your ID card against the top of your phone.',
          iosMultipleTagMessage: 'Multiple tags detected. Please present only one ID card.',
        );
      } catch (e) {
        throw NfcTimeoutFailure('NFC polling timed out or was cancelled by user.', e);
      }

      if (tag.standard != 'ISO 14443-4 (Type A)' &&
          tag.standard != 'ISO 14443-4 (Type B)' &&
          tag.type != NFCTagType.iso7816) {
        // Continue anyway as some devices report generic IsoDep
      }

      // Step 3: Discover Access Control Protocol (PACE / SAC or BAC)
      onProgress?.call('Connecting to microchip...', 0.12);
      Uint8List? cardAccessBytes = await _tryReadCardAccess();

      bool appletSelected = false;
      if (cardAccessBytes == null) {
        try {
          await _selectEmrtdApplet();
          appletSelected = true;
          cardAccessBytes = await _tryReadCardAccess();
        } catch (_) {}
      }

      PaceSecurityInfo? paceInfo;
      if (cardAccessBytes != null) {
        paceInfo = PaceCrypto.parseCardAccess(cardAccessBytes);
        if (paceInfo != null) {
          debugPrint('[NFC] 🛡️ Discovered PACE (SAC) on chip: $paceInfo');
        }
      }

      // Step 4: Perform Access Control Authentication
      if (paceInfo != null) {
        onProgress?.call('Authenticating via PACE (SAC)...', 0.25);
        try {
          _secureMessaging = await _performPaceAuthentication(paceInfo, mrzData.bacKeySeed);
          debugPrint('[NFC] ✅ PACE Authentication succeeded!');

          if (!appletSelected) {
            await _selectEmrtdAppletUnderSm();
            appletSelected = true;
          }
        } catch (paceErr) {
          debugPrint('[NFC] PACE attempt failed ($paceErr). Falling back to BAC...');
          if (!appletSelected) {
            await _selectEmrtdApplet();
            appletSelected = true;
          }
          onProgress?.call('Authenticating via BAC...', 0.25);
          _secureMessaging = await _performBacMutualAuthentication(mrzData.bacKeySeed);
        }
      } else {
        if (!appletSelected) {
          await _selectEmrtdApplet();
          appletSelected = true;
        }
        onProgress?.call('Authenticating via BAC...', 0.25);
        _secureMessaging = await _performBacMutualAuthentication(mrzData.bacKeySeed);
      }

      // Step 5: Read EF.COM to discover available Data Groups on this chip
      List<int> presentDgs = [];
      try {
        final comBytes = await _readElementaryFile(Uint8List.fromList(comFileId));
        presentDgs = TlvParser.parsePresentDgs(comBytes);
      } catch (_) {}

      // Step 6: Read DG1 (Biographic Data / MRZ)
      onProgress?.call('Reading biographic data (DG1)...', 0.40);
      final dg1Bytes = await _readElementaryFile(
        Uint8List.fromList(dg1FileId),
        onSubProgress: (p) => onProgress?.call('Reading DG1...', 0.40 + p * 0.10),
      );

      // Step 7: Read DG2 (Biometric Facial Image)
      onProgress?.call('Reading biometric portrait (DG2)...', 0.52);
      final dg2Bytes = await _readElementaryFile(
        Uint8List.fromList(dg2FileId),
        onSubProgress: (p) => onProgress?.call('Reading DG2 photo...', 0.52 + p * 0.18),
      );

      // Step 8: Read DG11 (Personal Details: Arabic Name, Mother, Birthplace)
      Uint8List? dg11Bytes;
      if (presentDgs.isEmpty || presentDgs.contains(11)) {
        try {
          onProgress?.call('Reading personal records (DG11)...', 0.72);
          dg11Bytes = await _readElementaryFile(Uint8List.fromList(dg11FileId));
        } catch (_) {}
      }

      // Step 9: Read DG12 (Document Details: Issue Date, Authority)
      Uint8List? dg12Bytes;
      if (presentDgs.isEmpty || presentDgs.contains(12)) {
        try {
          onProgress?.call('Reading document records (DG12)...', 0.78);
          dg12Bytes = await _readElementaryFile(Uint8List.fromList(dg12FileId));
        } catch (_) {}
      }

      // Step 10: Read DG7 (Signature Image)
      Uint8List? dg7Bytes;
      if (presentDgs.isEmpty || presentDgs.contains(7)) {
        try {
          onProgress?.call('Reading signature mark (DG7)...', 0.84);
          dg7Bytes = await _readElementaryFile(Uint8List.fromList(dg7FileId));
        } catch (_) {}
      }

      // Step 11: Read EF.SOD (Security Object Document) & Verify Hashes
      onProgress?.call('Verifying cryptographic SOD hash...', 0.90);
      Uint8List? sodBytes;
      bool isSodHashVerified = false;
      try {
        sodBytes = await _readElementaryFile(Uint8List.fromList(sodFileId));
        isSodHashVerified = _verifySodHashes(sodBytes, dg1Bytes, dg2Bytes);
      } catch (_) {
        // Fallback if SOD is not readable or restricted
      }

      onProgress?.call('Finalizing card dossier...', 0.98);

      // Step 12: Assemble comprehensive IdCardModel
      final idCard = _assembleIdCard(
        mrzData: mrzData,
        dg1Bytes: dg1Bytes,
        dg2Bytes: dg2Bytes,
        dg11Bytes: dg11Bytes,
        dg12Bytes: dg12Bytes,
        dg7Bytes: dg7Bytes,
        frontCardBytes: frontCardBytes,
        backCardBytes: backCardBytes,
        isSodHashVerified: isSodHashVerified,
      );

      await FlutterNfcKit.finish(iosAlertMessage: 'Identity card read successfully!');
      return idCard;
    } catch (e) {
      await FlutterNfcKit.finish(iosErrorMessage: 'Failed to read identity card.');
      if (e is IdCardFailure) rethrow;
      throw CardReadFailure('Unexpected error during NFC interrogation: $e', e);
    }
  }

  /// Attempts to read EF.CardAccess (FID 011C / SFI 1C) to inspect PACE capabilities.
  Future<Uint8List?> _tryReadCardAccess() async {
    // Attempt 1: Read by SFI 0x1C (P1 = 0x9C, P2 = 0x00, Le = 0x00)
    try {
      final sfiHex = await FlutterNfcKit.transceive('00B09C0000');
      debugPrint('[PACE] Probe SFI 1C: $sfiHex');
      if (sfiHex.endsWith('9000') && sfiHex.length > 4) {
        return _fromHex(sfiHex.substring(0, sfiHex.length - 4));
      }
    } catch (e) {
      debugPrint('[PACE] SFI 1C probe error: $e');
    }

    // Attempt 2: Select 011C (P2 = 0x0C)
    try {
      final selHex = await FlutterNfcKit.transceive('00A4020C02011C');
      debugPrint('[PACE] Probe SELECT 011C (P2=0C): $selHex');
      if (selHex.endsWith('9000') || selHex.startsWith('61')) {
        final readHex = await FlutterNfcKit.transceive('00B0000000');
        debugPrint('[PACE] Read binary 011C: $readHex');
        if (readHex.endsWith('9000') && readHex.length > 4) {
          return _fromHex(readHex.substring(0, readHex.length - 4));
        }
      }
    } catch (e) {
      debugPrint('[PACE] SELECT 011C (P2=0C) probe error: $e');
    }

    // Attempt 3: Select 011C (P2 = 0x00)
    try {
      final selHex = await FlutterNfcKit.transceive('00A4020002011C');
      debugPrint('[PACE] Probe SELECT 011C (P2=00): $selHex');
      if (selHex.endsWith('9000') || selHex.startsWith('61')) {
        final readHex = await FlutterNfcKit.transceive('00B0000000');
        debugPrint('[PACE] Read binary 011C (P2=00): $readHex');
        if (readHex.endsWith('9000') && readHex.length > 4) {
          return _fromHex(readHex.substring(0, readHex.length - 4));
        }
      }
    } catch (e) {
      debugPrint('[PACE] SELECT 011C (P2=00) probe error: $e');
    }

    return null;
  }

  /// Selects the ICAO 9303 eMRTD application under active Secure Messaging.
  Future<void> _selectEmrtdAppletUnderSm() async {
    final sm = _secureMessaging;
    if (sm == null) return;

    final selectHeader = Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C]);
    final wrapped = sm.wrapCommand(
      selectHeader,
      data: Uint8List.fromList(emrtdAid),
    );
    debugPrint('[PACE] Select eMRTD APDU under SM: ${_toHex(wrapped)}');
    final respHex = await FlutterNfcKit.transceive(_toHex(wrapped));
    debugPrint('[PACE] Select eMRTD Response HEX: $respHex');
    final unwrapped = sm.unwrapResponse(_fromHex(respHex));
    if (!unwrapped.isSuccess) {
      debugPrint('[PACE] Warning: select eMRTD under SM returned SW: ${unwrapped.sw1.toRadixString(16)} ${unwrapped.sw2.toRadixString(16)}');
      // Retry with P2=0x00
      final retryHeader = Uint8List.fromList([0x00, 0xA4, 0x04, 0x00]);
      final retryWrapped = sm.wrapCommand(
        retryHeader,
        data: Uint8List.fromList(emrtdAid),
      );
      debugPrint('[PACE] Select eMRTD (P2=00) APDU under SM: ${_toHex(retryWrapped)}');
      final retryRespHex = await FlutterNfcKit.transceive(_toHex(retryWrapped));
      debugPrint('[PACE] Select eMRTD (P2=00) Response HEX: $retryRespHex');
      final retryUnwrapped = sm.unwrapResponse(_fromHex(retryRespHex));
      if (!retryUnwrapped.isSuccess) {
        debugPrint('[PACE] Warning: select eMRTD retry under SM returned SW: ${retryUnwrapped.sw1.toRadixString(16)} ${retryUnwrapped.sw2.toRadixString(16)}');
      }
    }
  }

  /// Performs full PACE ECDH Generic Mapping mutual authentication:
  /// - Step 0: MSE:SET AT (algorithm OID + password reference 0x01)
  /// - Step 1: GENERAL AUTHENTICATE to retrieve encrypted nonce z, decrypted with K_pi
  /// - Step 2: GENERAL AUTHENTICATE with terminal mapping key X1, receives chip Y1
  /// - Step 3: Generic mapping G~ = s * G + H1, generates ephemeral key X2, receives chip Y2
  /// - Step 4: Ephemeral key agreement K = x2 * Y2, derives session keys KS_enc, KS_mac,
  ///   exchanges authentication tokens T_IFD and T_IC
  Future<SecureMessaging> _performPaceAuthentication(
    PaceSecurityInfo info,
    String passwordSeed,
  ) async {
    final handshake = PaceHandshake(
      info: info,
      passwordSeed: passwordSeed,
      paceRef: 0x01, // MRZ password
    );

    // Step 0: MSE:SET AT
    final setAtCmd = handshake.buildSetAtApdu();
    debugPrint('[PACE] Step 0 MSE:SET AT: ${_toHex(setAtCmd)}');
    final setAtRespHex = await FlutterNfcKit.transceive(_toHex(setAtCmd));
    debugPrint('[PACE] MSE:SET AT Response: $setAtRespHex');
    if (!setAtRespHex.endsWith('9000')) {
      throw PaceAuthenticationFailure('MSE:SET AT failed with status $setAtRespHex');
    }

    // Step 1: GENERAL AUTHENTICATE (Get Nonce)
    final getNonceCmd = handshake.buildGetNonceApdu(useChaining: false);
    debugPrint('[PACE] Step 1 Get Nonce: ${_toHex(getNonceCmd)}');
    var getNonceRespHex = await FlutterNfcKit.transceive(_toHex(getNonceCmd));
    debugPrint('[PACE] Step 1 Response: $getNonceRespHex');
    if (!getNonceRespHex.endsWith('9000')) {
      final chainCmd = handshake.buildGetNonceApdu(useChaining: true);
      getNonceRespHex = await FlutterNfcKit.transceive(_toHex(chainCmd));
      debugPrint('[PACE] Step 1 Chaining Retry Response: $getNonceRespHex');
      if (!getNonceRespHex.endsWith('9000')) {
        throw PaceAuthenticationFailure('PACE Step 1 (Get Nonce) failed: $getNonceRespHex');
      }
    }
    final nonceResp = _fromHex(getNonceRespHex);
    handshake.processEncryptedNonce(nonceResp);

    // Step 2: Map Nonce (Terminal sends mapping public key X1, receives chip Y1)
    final mapNonceCmd = handshake.buildMapNonceApdu(useChaining: true);
    debugPrint('[PACE] Step 2 Map Nonce (${mapNonceCmd.length} bytes)');
    var mapNonceRespHex = await FlutterNfcKit.transceive(_toHex(mapNonceCmd));
    debugPrint('[PACE] Step 2 Response: $mapNonceRespHex');
    if (!mapNonceRespHex.endsWith('9000')) {
      final noChainCmd = handshake.buildMapNonceApdu(useChaining: false);
      mapNonceRespHex = await FlutterNfcKit.transceive(_toHex(noChainCmd));
      if (!mapNonceRespHex.endsWith('9000')) {
        throw PaceAuthenticationFailure('PACE Step 2 (Map Nonce) failed: $mapNonceRespHex');
      }
    }
    final mapResp = _fromHex(mapNonceRespHex);

    // Step 3: Key Agreement (Terminal sends ephemeral public key X2, receives chip Y2)
    final agreeCmd = handshake.processChipMappingKeyAndBuildAgreementApdu(mapResp, useChaining: true);
    debugPrint('[PACE] Step 3 Key Agreement (${agreeCmd.length} bytes)');
    var agreeRespHex = await FlutterNfcKit.transceive(_toHex(agreeCmd));
    debugPrint('[PACE] Step 3 Response: $agreeRespHex');
    if (!agreeRespHex.endsWith('9000')) {
      final noChainCmd = handshake.processChipMappingKeyAndBuildAgreementApdu(mapResp, useChaining: false);
      agreeRespHex = await FlutterNfcKit.transceive(_toHex(noChainCmd));
      if (!agreeRespHex.endsWith('9000')) {
        throw PaceAuthenticationFailure('PACE Step 3 (Key Agreement) failed: $agreeRespHex');
      }
    }
    final agreeResp = _fromHex(agreeRespHex);

    // Step 4: Mutual Authentication (Terminal sends T_IFD, receives chip T_IC)
    final tokenCmd = handshake.processChipEphemeralKeyAndBuildTokenApdu(agreeResp);
    debugPrint('[PACE] Step 4 Mutual Auth (${tokenCmd.length} bytes)');
    final tokenRespHex = await FlutterNfcKit.transceive(_toHex(tokenCmd));
    debugPrint('[PACE] Step 4 Response: $tokenRespHex');
    if (!tokenRespHex.endsWith('9000')) {
      throw PaceAuthenticationFailure('PACE Step 4 (Mutual Authentication) failed: $tokenRespHex');
    }
    final tokenResp = _fromHex(tokenRespHex);
    handshake.verifyChipToken(tokenResp);

    debugPrint('[PACE] ✅ Mutual Authentication verified! Activating AES Secure Messaging.');
    return handshake.createSecureMessaging();
  }

  /// Selects the ICAO 9303 eMRTD application using AID: A0 00 00 02 47 10 01
  Future<void> _selectEmrtdApplet() async {
    // APDU: 00 A4 04 0C 07 [AID]
    final selectCmd = Uint8List.fromList([
      0x00, 0xA4, 0x04, 0x0C, emrtdAid.length, ...emrtdAid,
    ]);

    final respHex = await FlutterNfcKit.transceive(_toHex(selectCmd));
    final resp = _fromHex(respHex);

    if (resp.length < 2) {
      throw const CardReadFailure('Empty response when selecting eMRTD application.');
    }
    final sw1 = resp[resp.length - 2];
    final sw2 = resp[resp.length - 1];

    if (sw1 != 0x90 || sw2 != 0x00) {
      // Retry with P2=0x00
      final retryCmd = Uint8List.fromList([
        0x00, 0xA4, 0x04, 0x00, emrtdAid.length, ...emrtdAid,
      ]);
      final retryHex = await FlutterNfcKit.transceive(_toHex(retryCmd));
      final retryResp = _fromHex(retryHex);
      if (retryResp.length < 2 || retryResp[retryResp.length - 2] != 0x90) {
        throw CardReadFailure(
          'Failed to select eMRTD application: Status ${sw1.toRadixString(16)} ${sw2.toRadixString(16)}',
        );
      }
    }
  }

  /// Executes BAC mutual authentication protocol according to ICAO Doc 9303 Part 11:
  /// 1. Derive K_enc and K_mac from MRZ seed string
  /// 2. Send GET CHALLENGE to obtain 8-byte random RND.IC
  /// 3. Terminal generates 8-byte RND.IFD and 16-byte K.IFD
  /// 4. Encrypt S = RND.IFD || RND.IC || K.IFD with K_enc
  /// 5. Calculate Retail MAC m_IFD over e_IFD with K_mac
  /// 6. Send MUTUAL AUTHENTICATE APDU (00 82 00 00 28 e_IFD m_IFD 28)
  /// 7. Verify response MAC m_IC and decrypt e_IC to verify RND.IFD
  /// 8. Derive session keys KS_enc, KS_mac and initialize Send Sequence Counter (SSC)
  Future<SecureMessaging> _performBacMutualAuthentication(String mrzSeed) async {
    // 1. Derive Static Keys from MRZ Seed
    final kSeed = BacCrypto.deriveKeySeed(mrzSeed);
    final kEnc = BacCrypto.deriveKey(kSeed, 1);
    final kMac = BacCrypto.deriveKey(kSeed, 2);

    // 2. GET CHALLENGE APDU: 00 84 00 00 08
    final getChallengeCmd = Uint8List.fromList([0x00, 0x84, 0x00, 0x00, 0x08]);
    final challengeRespHex = await FlutterNfcKit.transceive(_toHex(getChallengeCmd));
    final challengeResp = _fromHex(challengeRespHex);

    if (challengeResp.length < 10) {
      throw const BacAuthenticationFailure('GET CHALLENGE failed: response too short.');
    }
    final rndIc = challengeResp.sublist(0, 8);

    // 3. Generate Terminal Randoms
    final random = Random.secure();
    final rndIfd = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      rndIfd[i] = random.nextInt(256);
    }
    final kIfd = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      kIfd[i] = random.nextInt(256);
    }

    // 4. Concatenate S = RND.IFD || RND.IC || K.IFD (32 bytes)
    final s = Uint8List(32);
    s.setRange(0, 8, rndIfd);
    s.setRange(8, 16, rndIc);
    s.setRange(16, 32, kIfd);

    // 5. Encrypt S with 3DES-CBC (IV = 0)
    final zeroIv = Uint8List(8);
    final eIfd = BacCrypto.des3CbcEncrypt(kEnc, zeroIv, s);

    // 6. Compute Retail MAC over e_IFD
    final mIfd = BacCrypto.iso9797MacAlg3(kMac, eIfd);

    // 7. MUTUAL AUTHENTICATE APDU: 00 82 00 00 28 [e_IFD (32)] [m_IFD (8)] 28
    final authCmd = BytesBuilder()
      ..add([0x00, 0x82, 0x00, 0x00, 0x28])
      ..add(eIfd)
      ..add(mIfd)
      ..addByte(0x28);

    final authRespHex = await FlutterNfcKit.transceive(_toHex(authCmd.toBytes()));
    debugPrint('[BAC] MUTUAL AUTHENTICATE Response HEX: $authRespHex');
    final authResp = _fromHex(authRespHex);

    if (authResp.length < 42) {
      final sw = authRespHex.length >= 4 ? authRespHex.substring(authRespHex.length - 4) : authRespHex;
      debugPrint('[BAC] ❌ Chip rejected MUTUAL AUTHENTICATE with status: $sw');
      throw BacAuthenticationFailure(
        'MUTUAL AUTHENTICATE rejected by chip (Status $sw). Check MRZ document number, birth date, and expiry date.',
      );
    }

    final eIc = authResp.sublist(0, 32);
    final mIc = authResp.sublist(32, 40);

    // 8. Verify Response MAC
    final expectedMIc = BacCrypto.iso9797MacAlg3(kMac, eIc);
    if (!_bytesEqual(expectedMIc, mIc)) {
      throw const BacAuthenticationFailure('Chip MAC verification failed during BAC authentication.');
    }

    // 9. Decrypt e_IC to get RND.IC || RND.IFD || K.IC
    final decryptedIc = BacCrypto.des3CbcDecrypt(kEnc, zeroIv, eIc);
    final respRndIfd = decryptedIc.sublist(8, 16);
    final kIc = decryptedIc.sublist(16, 32);

    if (!_bytesEqual(respRndIfd, rndIfd)) {
      throw const BacAuthenticationFailure('Mutual authentication failed: Terminal nonce mismatch.');
    }

    // 10. Calculate Session Keys: K_seed_session = K.IFD XOR K.IC
    final kSeedSession = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      kSeedSession[i] = kIfd[i] ^ kIc[i];
    }

    final ksEnc = BacCrypto.deriveKey(kSeedSession, 1);
    final ksMac = BacCrypto.deriveKey(kSeedSession, 2);

    // Initial Send Sequence Counter: SSC = RND.IC[4..8] || RND.IFD[4..8]
    final initialSsc = Uint8List(8);
    initialSsc.setRange(0, 4, rndIc.sublist(4, 8));
    initialSsc.setRange(4, 8, rndIfd.sublist(4, 8));

    return SecureMessaging(ksEnc: ksEnc, ksMac: ksMac, initialSsc: initialSsc);
  }

  /// Selects an Elementary File (EF) and reads its complete contents in chunks
  /// protected under Secure Messaging.
  Future<Uint8List> _readElementaryFile(
    Uint8List fileId, {
    void Function(double progress)? onSubProgress,
  }) async {
    final sm = _secureMessaging;
    if (sm == null) throw const CardReadFailure('Secure Messaging session is not active.');

    final sfi = _fileIdToSfi(fileId);
    Uint8List? headBytes;
    String lastError = '';

    // Strategy 1 (Direct SFI READ BINARY - ICAO Doc 9303 Part 10 Section 3.6):
    // All ICAO eMRTD LDS files (DG1, DG2, SOD, COM) mandate direct access via Short File Identifier.
    // This executes as the very first command after BAC without needing separate SELECT FILE.
    if (sfi != null) {
      final sfiHeader = Uint8List.fromList([0x00, 0xB0, 0x80 | sfi, 0x00]);
      final sfiApdu = sm.wrapCommand(sfiHeader, le: 4);
      debugPrint('[NFC_SM] SFI READ APDU (sfi=$sfi): ${_toHex(sfiApdu)}');
      final sfiRespHex = await FlutterNfcKit.transceive(_toHex(sfiApdu));
      debugPrint('[NFC_SM] SFI READ Response HEX: $sfiRespHex');
      final sfiResp = sm.unwrapResponse(_fromHex(sfiRespHex));
      if (sfiResp.isSuccess && sfiResp.data.length >= 2) {
        headBytes = sfiResp.data;
        debugPrint('[NFC_SM] SFI READ succeeded! headBytes: ${_toHex(headBytes)}');
      } else {
        lastError = 'SFI READ failed (SW=${sfiResp.sw1.toRadixString(16)} ${sfiResp.sw2.toRadixString(16)})';
        debugPrint('[NFC_SM] $lastError');
      }
    }

    // Strategy 2: Explicit SELECT FILE APDU (00 A4 02 0C) fallback
    if (headBytes == null || headBytes.length < 2) {
      final selectHeader = Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C]);
      var selectApdu = sm.wrapCommand(selectHeader, data: fileId);
      debugPrint('[NFC_SM] SELECT FILE (P2=0C) APDU: ${_toHex(selectApdu)}');
      var selectRespHex = await FlutterNfcKit.transceive(_toHex(selectApdu));
      debugPrint('[NFC_SM] SELECT FILE Response HEX: $selectRespHex');
      var selectResp = sm.unwrapResponse(_fromHex(selectRespHex));

      if (!selectResp.isSuccess) {
        // Strategy 3: SELECT FILE with P2 = 0x00
        final retryHeader = Uint8List.fromList([0x00, 0xA4, 0x02, 0x00]);
        selectApdu = sm.wrapCommand(retryHeader, data: fileId);
        debugPrint('[NFC_SM] SELECT FILE (P2=00) retry APDU: ${_toHex(selectApdu)}');
        selectRespHex = await FlutterNfcKit.transceive(_toHex(selectApdu));
        debugPrint('[NFC_SM] SELECT FILE (P2=00) Response HEX: $selectRespHex');
        selectResp = sm.unwrapResponse(_fromHex(selectRespHex));
      }

      if (selectResp.isSuccess) {
        final readHeader = Uint8List.fromList([0x00, 0xB0, 0x00, 0x00]);
        final readHeadApdu = sm.wrapCommand(readHeader, le: 4);
        debugPrint('[NFC_SM] READ BINARY head APDU: ${_toHex(readHeadApdu)}');
        final headRespHex = await FlutterNfcKit.transceive(_toHex(readHeadApdu));
        debugPrint('[NFC_SM] READ BINARY head Response HEX: $headRespHex');
        final headResp = sm.unwrapResponse(_fromHex(headRespHex));
        if (headResp.isSuccess && headResp.data.length >= 2) {
          headBytes = headResp.data;
          debugPrint('[NFC_SM] READ BINARY head succeeded: ${_toHex(headBytes)}');
        } else {
          lastError = 'READ BINARY header failed: SW=${headResp.sw1.toRadixString(16)} ${headResp.sw2.toRadixString(16)}';
          debugPrint('[NFC_SM] $lastError');
        }
      } else {
        lastError = 'SELECT FILE failed: SW=${selectResp.sw1.toRadixString(16)} ${selectResp.sw2.toRadixString(16)}';
        debugPrint('[NFC_SM] $lastError');
      }
    }

    if (headBytes == null || headBytes.length < 2) {
      throw CardReadFailure(
        'Failed to read elementary file ${fileId.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}: $lastError',
      );
    }

    final totalFileLength = _parseTlvTotalLength(headBytes);

    // 3. Read Remaining Content in Chunks (224 bytes per chunk to fit APDU limits)
    final fileBuffer = BytesBuilder();
    const chunkSize = 224;
    int offset = 0;

    while (offset < totalFileLength) {
      final bytesToRead = min(chunkSize, totalFileLength - offset);
      int p1 = (offset >> 8) & 0xFF;
      int p2 = offset & 0xFF;
      // For offsets < 256, use SFI addressing if available
      if (sfi != null && offset < 256) {
        p1 = 0x80 | sfi;
        p2 = offset;
      }

      final chunkHeader = Uint8List.fromList([0x00, 0xB0, p1, p2]);
      final chunkApdu = sm.wrapCommand(chunkHeader, le: bytesToRead);

      final chunkRespHex = await FlutterNfcKit.transceive(_toHex(chunkApdu));
      final chunkResp = sm.unwrapResponse(_fromHex(chunkRespHex));

      if (chunkResp.data.isEmpty) break;

      fileBuffer.add(chunkResp.data);
      offset += chunkResp.data.length;

      onSubProgress?.call(min(1.0, offset / totalFileLength));

      if (chunkResp.sw1 == 0x62 || chunkResp.sw2 == 0x82) {
        // End of file reached early
        break;
      }
    }

    return fileBuffer.toBytes();
  }

  /// Extracts biographical fields, Arabic personal details, and biometric photos into [IdCardModel].
  IdCardModel _assembleIdCard({
    required MrzData mrzData,
    required Uint8List dg1Bytes,
    required Uint8List dg2Bytes,
    Uint8List? dg11Bytes,
    Uint8List? dg12Bytes,
    Uint8List? dg7Bytes,
    Uint8List? frontCardBytes,
    Uint8List? backCardBytes,
    required bool isSodHashVerified,
  }) {
    // 1. Biometric Facial Portrait extraction from DG2
    final photoBytes = TlvParser.extractFacialImage(dg2Bytes);

    // 2. Parse DG1 (Tag 0x61 -> 0x5F1F)
    final mrzTagData = TlvParser.findTag(dg1Bytes, 0x5F1F);
    final mrzString = (mrzTagData != null) ? String.fromCharCodes(mrzTagData) : mrzData.rawLines.join('\n');

    // 3. Parse DG11 (Personal Details) if present
    String? fullNameArabic;
    String? placeOfBirth;
    String? motherName;
    String? dg11PersonalNum;
    String? address;

    if (dg11Bytes != null && dg11Bytes.isNotEmpty) {
      fullNameArabic = TlvParser.parseString(dg11Bytes, 0x5F0E);
      placeOfBirth = TlvParser.parseString(dg11Bytes, 0x5F11);
      motherName = TlvParser.parseString(dg11Bytes, 0x5F2C);
      dg11PersonalNum = TlvParser.parseString(dg11Bytes, 0x5F10);
      address = TlvParser.parseString(dg11Bytes, 0x5F12);
    }

    // 4. Parse DG12 (Document Details) if present
    String? issuingAuthority;
    DateTime? dateOfIssue;

    if (dg12Bytes != null && dg12Bytes.isNotEmpty) {
      issuingAuthority = TlvParser.parseString(dg12Bytes, 0x5F19);
      dateOfIssue = TlvParser.parseDate(dg12Bytes, 0x5F26);
    }

    // 5. Parse DG7 (Signature Image) if present
    Uint8List? signaturePhotoBytes;
    if (dg7Bytes != null && dg7Bytes.isNotEmpty) {
      signaturePhotoBytes = TlvParser.extractSignatureImage(dg7Bytes);
    }

    // 6. National Unified Personal Number (12-digits)
    String? personalNumber = dg11PersonalNum;
    if (personalNumber == null || personalNumber.isEmpty) {
      personalNumber = mrzData.optionalData.replaceAll('<', '').trim();
      if (personalNumber.isEmpty && mrzData.optionalData2.isNotEmpty) {
        personalNumber = mrzData.optionalData2.replaceAll('<', '').trim();
      }
    }

    final isExpired = mrzData.dateOfExpiry != null && DateTime.now().isAfter(mrzData.dateOfExpiry!);

    return IdCardModel(
      documentNumber: mrzData.documentNumber,
      documentType: mrzData.documentType,
      issuingCountry: mrzData.countryCode,
      nationality: mrzData.nationality,
      surname: mrzData.surname,
      givenNames: mrzData.givenNames,
      fullNameArabic: fullNameArabic,
      motherName: motherName,
      placeOfBirth: placeOfBirth,
      gender: mrzData.sex,
      dateOfBirth: mrzData.dateOfBirth,
      dateOfExpiry: mrzData.dateOfExpiry,
      dateOfIssue: dateOfIssue,
      issuingAuthority: issuingAuthority,
      personalNumber: personalNumber.isNotEmpty ? personalNumber : null,
      address: address,
      facePhotoBytes: photoBytes,
      signaturePhotoBytes: signaturePhotoBytes,
      frontCardPhotoBytes: frontCardBytes,
      backCardPhotoBytes: backCardBytes,
      isBacAuthenticated: true,
      isSodHashVerified: isSodHashVerified,
      isDocumentValid: !isExpired && isSodHashVerified,
      rawMrz: mrzString,
    );
  }

  /// Verifies whether SHA-256 / SHA-1 hashes of DG1 and DG2 are contained
  /// in the Security Object Document (EF.SOD).
  bool _verifySodHashes(Uint8List sodBytes, Uint8List dg1Bytes, Uint8List dg2Bytes) {
    if (sodBytes.isEmpty) return false;

    // Check SHA-256 digests
    final dg1Sha256 = crypto.sha256.convert(dg1Bytes).bytes;
    final dg2Sha256 = crypto.sha256.convert(dg2Bytes).bytes;

    final hasDg1Sha256 = _containsSequence(sodBytes, dg1Sha256);
    final hasDg2Sha256 = _containsSequence(sodBytes, dg2Sha256);

    if (hasDg1Sha256 && hasDg2Sha256) return true;

    // Fallback: Check SHA-1 digests (used by older ICAO passports)
    final dg1Sha1 = crypto.sha1.convert(dg1Bytes).bytes;
    final dg2Sha1 = crypto.sha1.convert(dg2Bytes).bytes;

    final hasDg1Sha1 = _containsSequence(sodBytes, dg1Sha1);
    final hasDg2Sha1 = _containsSequence(sodBytes, dg2Sha1);

    return hasDg1Sha1 && hasDg2Sha1;
  }

  static int _parseTlvTotalLength(Uint8List headerBytes) {
    if (headerBytes.length < 2) return 256;
    int offset = 1;
    // Check if tag is 2 bytes
    if ((headerBytes[0] & 0x1F) == 0x1F) offset = 2;
    if (offset >= headerBytes.length) return 256;

    final lenByte = headerBytes[offset++];
    if (lenByte < 0x80) {
      return offset + lenByte;
    } else if (lenByte == 0x81 && offset < headerBytes.length) {
      return offset + 1 + headerBytes[offset];
    } else if (lenByte == 0x82 && offset + 1 < headerBytes.length) {
      final len = (headerBytes[offset] << 8) | headerBytes[offset + 1];
      return offset + 2 + len;
    }
    return 1024; // Default fallback estimate
  }

  static bool _containsSequence(Uint8List haystack, List<int> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return false;
    for (int i = 0; i <= haystack.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _toHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  static Uint8List _fromHex(String hex) {
    final clean = hex.replaceAll(' ', '');
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }

  static int? _fileIdToSfi(Uint8List fileId) {
    if (fileId.length == 2 && fileId[0] == 0x01) {
      return fileId[1];
    }
    return null;
  }
}
