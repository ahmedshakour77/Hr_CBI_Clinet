import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../data/datasources/mrz_scanner_service.dart';
import '../../data/datasources/nfc_passport_reader_service.dart';
import '../../domain/entities/id_card_model.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/errors/id_card_failure.dart';

enum DocumentTypeMode {
  /// البطاقة الوطنية الموحدة (وجه أمامي + وجه خلفي + NFC)
  nationalId,

  /// جواز السفر الإلكتروني البيومتري (صفحة البيانات + NFC)
  electronicPassport,

  /// جواز السفر العادي (صفحة البيانات - قراءة بصرية MRZ فقط دون شريحة)
  regularPassport,
}

sealed class IdReaderState {
  const IdReaderState();
}

class IdReaderInitial extends IdReaderState {
  const IdReaderInitial();
}

/// Prompting user to capture the front face of the ID card
class IdReaderScanningFront extends IdReaderState {
  const IdReaderScanningFront();
}

/// Prompting user to scan the MRZ on the back of the ID card or the passport page
class IdReaderScanningBack extends IdReaderState {
  const IdReaderScanningBack({this.frontCardBytes});
  final Uint8List? frontCardBytes;
}

/// MRZ and back photo successfully captured
class IdReaderMrzCaptured extends IdReaderState {
  const IdReaderMrzCaptured({
    required this.mrzData,
    this.frontCardBytes,
    this.backCardBytes,
  });

  final MrzData mrzData;
  final Uint8List? frontCardBytes;
  final Uint8List? backCardBytes;
}

class IdReaderNfcReading extends IdReaderState {
  const IdReaderNfcReading({
    required this.mrzData,
    required this.stepDescription,
    required this.progress,
    this.frontCardBytes,
    this.backCardBytes,
  });

  final MrzData mrzData;
  final String stepDescription;
  final double progress;
  final Uint8List? frontCardBytes;
  final Uint8List? backCardBytes;
}

class IdReaderSuccess extends IdReaderState {
  const IdReaderSuccess(this.idCard);
  final IdCardModel idCard;
}

class IdReaderError extends IdReaderState {
  const IdReaderError(this.failure);
  final IdCardFailure failure;
}

/// Controller managing state transitions between Front/Back camera capture,
/// MRZ parsing, NFC chip interrogation, and final document dossier assembly.
class IdReaderController extends ChangeNotifier {
  IdReaderController({
    MrzScannerService? mrzScannerService,
    NfcPassportReaderService? nfcReaderService,
    DocumentTypeMode initialMode = DocumentTypeMode.nationalId,
  })  : _mrzScannerService = mrzScannerService ?? MrzScannerService(),
        _nfcReaderService = nfcReaderService ?? NfcPassportReaderService(),
        _selectedMode = initialMode;

  final MrzScannerService _mrzScannerService;
  final NfcPassportReaderService _nfcReaderService;

  DocumentTypeMode _selectedMode;
  DocumentTypeMode get selectedMode => _selectedMode;

  IdReaderState _state = const IdReaderInitial();
  IdReaderState get state => _state;

  Uint8List? _frontCardBytes;
  Uint8List? _backCardBytes;

  Uint8List? get frontCardBytes => _frontCardBytes;
  Uint8List? get backCardBytes => _backCardBytes;

  void setDocumentMode(DocumentTypeMode mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    // Passports only have a single data page with MRZ
    if (mode == DocumentTypeMode.electronicPassport || mode == DocumentTypeMode.regularPassport) {
      startScanning(scanFrontFirst: false);
    } else {
      startScanning(scanFrontFirst: true);
    }
  }

  void startScanning({bool scanFrontFirst = true}) {
    // For passports, always scan the single data page with MRZ
    if (_selectedMode != DocumentTypeMode.nationalId) {
      scanFrontFirst = false;
    }

    if (scanFrontFirst) {
      _state = const IdReaderScanningFront();
    } else {
      _state = const IdReaderScanningBack();
    }
    notifyListeners();
  }

  void onFrontCaptured(Uint8List frontBytes) {
    _frontCardBytes = frontBytes;
    _state = IdReaderScanningBack(frontCardBytes: frontBytes);
    notifyListeners();
  }

  void skipFrontCapture() {
    _state = const IdReaderScanningBack();
    notifyListeners();
  }

  void completeWithMrzOnly(MrzData mrzData, {Uint8List? photoBytes}) {
    final photo = photoBytes ?? _frontCardBytes ?? _backCardBytes;
    final idCard = IdCardModel.fromMrzOnly(
      mrzData: mrzData,
      frontCardPhotoBytes: photo,
      backCardPhotoBytes: _backCardBytes,
    );
    _state = IdReaderSuccess(idCard);
    notifyListeners();
  }

  Future<void> onFrameCaptured(InputImage inputImage) async {
    if (_state is! IdReaderScanningBack) return;

    try {
      final mrz = await _mrzScannerService.processFrame(inputImage);
      if (mrz != null) {
        debugPrint('[ID_READER] ✅ MRZ Captured! Doc: ${mrz.documentNumber}, DOB: ${mrz.birthDateRaw}');
        _state = IdReaderMrzCaptured(
          mrzData: mrz,
          frontCardBytes: _frontCardBytes,
          backCardBytes: _backCardBytes,
        );
        notifyListeners();
      }
    } catch (_) {
      // Keep scanning on individual frame read errors
    }
  }

  void setBackCardBytes(Uint8List backBytes) {
    _backCardBytes = backBytes;
  }

  Future<void> startNfcReading(
    MrzData mrzData, {
    Uint8List? frontCardBytes,
    Uint8List? backCardBytes,
  }) async {
    final front = frontCardBytes ?? _frontCardBytes;
    final back = backCardBytes ?? _backCardBytes;

    debugPrint('[ID_READER] 📡 Starting NFC Reading for seed: ${mrzData.bacKeySeed}');
    _state = IdReaderNfcReading(
      mrzData: mrzData,
      stepDescription: 'Preparing NFC antenna...',
      progress: 0.05,
      frontCardBytes: front,
      backCardBytes: back,
    );
    notifyListeners();

    try {
      final idCard = await _nfcReaderService.readIdCard(
        mrzData: mrzData,
        frontCardBytes: front,
        backCardBytes: back,
        onProgress: (stepDescription, progress) {
          debugPrint('[ID_READER] ⏳ NFC Progress: ${(progress * 100).toInt()}% - $stepDescription');
          _state = IdReaderNfcReading(
            mrzData: mrzData,
            stepDescription: stepDescription,
            progress: progress,
            frontCardBytes: front,
            backCardBytes: back,
          );
          notifyListeners();
        },
      );

      debugPrint('[ID_READER] 🎉 NFC Read Successful! Name: ${idCard.displayName}');
      _state = IdReaderSuccess(idCard);
      notifyListeners();
    } on IdCardFailure catch (failure) {
      debugPrint('[ID_READER] ❌ Failure: ${failure.message}');
      _state = IdReaderError(failure);
      notifyListeners();
    } catch (e) {
      debugPrint('[ID_READER] ❌ Unexpected Error: $e');
      _state = IdReaderError(CardReadFailure('Unexpected error: $e', e));
      notifyListeners();
    }
  }

  void reset() {
    _frontCardBytes = null;
    _backCardBytes = null;
    _state = const IdReaderInitial();
    notifyListeners();
  }

  @override
  void dispose() {
    _mrzScannerService.dispose();
    super.dispose();
  }
}

