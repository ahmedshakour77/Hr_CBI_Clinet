/// Base exception class for all ID reading and NFC interrogation failures.
sealed class IdCardFailure implements Exception {
  const IdCardFailure(this.message, [this.details]);

  final String message;
  final dynamic details;

  @override
  String toString() => '$runtimeType: $message${details != null ? ' ($details)' : ''}';
}

/// Thrown when OCR text scanning fails to detect or validate an MRZ zone.
class MrzScanFailure extends IdCardFailure {
  const MrzScanFailure(super.message, [super.details]);
}

/// Thrown when the device hardware lacks NFC support or NFC is switched off.
class NfcUnavailableFailure extends IdCardFailure {
  const NfcUnavailableFailure(super.message, [super.details]);
}

/// Thrown when the NFC polling or reading session times out waiting for tag interaction.
class NfcTimeoutFailure extends IdCardFailure {
  const NfcTimeoutFailure(super.message, [super.details]);
}

/// Thrown when Basic Access Control (BAC) fails, typically due to mismatched
/// MRZ keys (e.g. incorrect document number or checksum OCR read error).
class BacAuthenticationFailure extends IdCardFailure {
  const BacAuthenticationFailure(super.message, [super.details]);
}

/// Thrown when Password Authenticated Connection Establishment (PACE) fails,
/// typically on modern SAC biometric passports.
class PaceAuthenticationFailure extends IdCardFailure {
  const PaceAuthenticationFailure(super.message, [super.details]);
}

/// Thrown when the physical connection to the chip is severed mid-operation.
class TagLostFailure extends IdCardFailure {
  const TagLostFailure(super.message, [super.details]);
}

/// Thrown when reading Elementary Files (EF.DG1, EF.DG2, EF.SOD) returns an error APDU.
class CardReadFailure extends IdCardFailure {
  const CardReadFailure(super.message, [super.details]);
}

/// Thrown when passive cryptographic verification (SOD signature / DG hashes) fails.
class SecurityVerificationFailure extends IdCardFailure {
  const SecurityVerificationFailure(super.message, [super.details]);
}
