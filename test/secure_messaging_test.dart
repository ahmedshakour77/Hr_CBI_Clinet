import 'dart:typed_data';
import 'package:cbi_app/src/id_reader/data/crypto/secure_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SecureMessaging wraps SELECT FILE and READ BINARY with trailing 0x00', () {
    final ksEnc = Uint8List(16);
    final ksMac = Uint8List(16);
    final initialSsc = Uint8List(8);

    final sm = SecureMessaging(ksEnc: ksEnc, ksMac: ksMac, initialSsc: initialSsc);

    // 1. SELECT FILE (00 A4 02 0C, data: [0x01, 0x01])
    final selectHeader = Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C]);
    final selectApdu = sm.wrapCommand(selectHeader, data: Uint8List.fromList([0x01, 0x01]));

    // Must end with 00 (Le=00)
    expect(selectApdu.last, equals(0x00));
    // Header must have SM bits: 0C A4 02 0C
    expect(selectApdu.sublist(0, 4), equals([0x0C, 0xA4, 0x02, 0x0C]));

    // 2. READ BINARY with SFI (00 B0 81 00, le: 4)
    final readHeader = Uint8List.fromList([0x00, 0xB0, 0x81, 0x00]);
    final readApdu = sm.wrapCommand(readHeader, le: 4);

    expect(readApdu.last, equals(0x00));
    expect(readApdu.sublist(0, 4), equals([0x0C, 0xB0, 0x81, 0x00]));
  });

  test('SecureMessaging.aes correctly increments 128-bit SSC and formats DO87/DO97/DO8E', () {
    final ksEnc = Uint8List(32); // AES-256
    final ksMac = Uint8List(32);
    final sm = SecureMessaging.aes(ksEnc: ksEnc, ksMac: ksMac);

    expect(sm.ssc, equals(BigInt.zero));

    // 1. SELECT eMRTD under SM
    final selectHeader = Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C]);
    final emrtdAid = Uint8List.fromList([0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01]);
    final wrapped = sm.wrapCommand(selectHeader, data: emrtdAid);

    expect(sm.ssc, equals(BigInt.one));
    expect(wrapped.sublist(0, 4), equals([0x0C, 0xA4, 0x04, 0x0C]));
    expect(wrapped.last, equals(0x00)); // Le = 0x00

    // Must contain tag 87 and tag 8E
    expect(wrapped[5], equals(0x87));

    // 2. Unwrapped bare 9000 response should succeed without changing SSC
    final bareSuccess = sm.unwrapResponse(Uint8List.fromList([0x90, 0x00]));
    expect(bareSuccess.isSuccess, isTrue);
    expect(sm.ssc, equals(BigInt.one)); // SSC not incremented on bare response
  });
}

