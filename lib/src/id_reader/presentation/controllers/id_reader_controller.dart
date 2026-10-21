import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../data/datasources/mrz_scanner_service.dart';
import '../../data/datasources/nfc_passport_reader_service.dart';
import '../../domain/entities/id_card_model.dart';
import '../../domain/entities/mrz_data.dart';
import '../../domain/errors/id_card_failure.dart';

enum DocumentTypeMode {
  nationalId,
  electronicPassport,
  regularPassport,
}

sealed class IdReaderState {
  const IdReaderState();
}

class IdReaderInitial extends IdReaderState {
  const IdReaderInitial();
}

class IdReaderScanningFront extends IdReaderState {
  const IdReaderScanningFront();
}

class IdReaderScanningBack extends IdReaderState {
  const IdReaderScanningBack({this.frontCardBytes});
  final Uint8List? frontCardBytes;
}

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
  int _operationGeneration = 0;
  bool _disposed = false;

  Uint8List? get frontCardBytes => _frontCardBytes;
  Uint8List? get backCardBytes => _backCardBytes;

  void _invalidatePendingOperations() {
    _operationGeneration++;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _operationGeneration;

  void setDocumentMode(DocumentTypeMode mode) {
    if (_selectedMode == mode) return;
    _selectedMode = mode;
    _frontCardBytes = null;
    _backCardBytes = null;
    _invalidatePendingOperations();
    startScanning(scanFrontFirst: mode == DocumentTypeMode.nationalId);
  }

  void startScanning({bool scanFrontFirst = true}) {
    _invalidatePendingOperations();
    _frontCardBytes = null;
    _backCardBytes = null;

    if (_selectedMode != DocumentTypeMode.nationalId) {
      scanFrontFirst = false;
    }

    _state = scanFrontFirst
        ? const IdReaderScanningFront()
        : const IdReaderScanningBack();
    notifyListeners();
  }

  void onFrontCaptured(Uint8List frontBytes) {
    _frontCardBytes = frontBytes;
    _state = IdReaderScanningBack(frontCardBytes: frontBytes);
    notifyListeners();
  }

  void skipFrontCapture() {
    _frontCardBytes = null;
    _state = const IdReaderScanningBack();
    notifyListeners();
  }

  void completeWithMrzOnly(MrzData mrzData, {Uint8List? photoBytes}) {
    _invalidatePendingOperations();
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
    final generation = _operationGeneration;

    try {
      final mrz = await _mrzScannerService.processFrame(inputImage);
      if (!_isCurrent(generation) || _state is! IdReaderScanningBack) return;
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
      // Keep scanning on individual frame read errors.
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
    _invalidatePendingOperations();
    final generation = _operationGeneration;
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
          if (!_isCurrent(generation)) return;
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

      if (!_isCurrent(generation)) return;
      debugPrint('[ID_READER] 🎉 NFC Read Successful! Name: ${idCard.displayName}');
      _state = IdReaderSuccess(idCard);
      notifyListeners();
    } on IdCardFailure catch (failure) {
      if (!_isCurrent(generation)) return;
      debugPrint('[ID_READER] ❌ Failure: ${failure.message}');
      _state = IdReaderError(failure);
      notifyListeners();
    } catch (e) {
      if (!_isCurrent(generation)) return;
      debugPrint('[ID_READER] ❌ Unexpected Error: $e');
      _state = IdReaderError(CardReadFailure('Unexpected error: $e', e));
      notifyListeners();
    }
  }

  /// Invalidates all pending OCR/NFC callbacks and clears document images.
  void reset() {
    _invalidatePendingOperations();
    _frontCardBytes = null;
    _backCardBytes = null;
    _state = const IdReaderInitial();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidatePendingOperations();
    _mrzScannerService.dispose();
    super.dispose();
  }
}
