import 'package:cbi_app/src/id_reader/domain/entities/id_card_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy weak SOD success cannot mark passive authentication as verified', () {
    const card = IdCardModel(
      documentNumber: 'A12345678',
      documentType: 'P',
      issuingCountry: 'IRQ',
      nationality: 'IRQ',
      surname: 'HASSAN',
      givenNames: 'ALI',
      gender: 'M',
      isBacAuthenticated: true,
      isSodHashVerified: true,
      isDocumentValid: true,
    );

    expect(card.isSodHashVerified, isFalse);
    expect(card.isDocumentValid, isFalse);
    expect(card.toApiPayload()['isPassiveAuthenticationValid'], isFalse);
  });

  test('non-expired optical-only document may be valid without crypto claim', () {
    const card = IdCardModel(
      documentNumber: 'A12345678',
      documentType: 'P',
      issuingCountry: 'IRQ',
      nationality: 'IRQ',
      surname: 'HASSAN',
      givenNames: 'ALI',
      gender: 'M',
      isSodHashVerified: false,
      isDocumentValid: true,
    );

    expect(card.isDocumentValid, isTrue);
    expect(card.isSodHashVerified, isFalse);
  });
}
