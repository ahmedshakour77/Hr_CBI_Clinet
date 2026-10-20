import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../auth/auth_controller.dart';
import '../../data/datasources/card_image_cropper.dart';
import '../controllers/id_reader_controller.dart';
import '../widgets/mrz_camera_overlay.dart';
import '../widgets/nfc_tapping_sheet.dart';
import 'id_details_view.dart';

/// Full-screen entry page providing guided MRZ camera scanning,
/// automated NFC chip interrogation, and result routing.
class IdReaderPage extends StatefulWidget {
  const IdReaderPage({
    super.key,
    this.targetEmployeeId,
    this.targetEmployeeName,
    this.auth,
    this.initialMode,
  });

  final String? targetEmployeeId;
  final String? targetEmployeeName;
  final AuthController? auth;
  final DocumentTypeMode? initialMode;

  @override
  State<IdReaderPage> createState() => _IdReaderPageState();
}

class _IdReaderPageState extends State<IdReaderPage> {
  final _controller = IdReaderController();
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      _controller.setDocumentMode(widget.initialMode!);
    }
    _controller.addListener(_onStateChanged);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Select back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

      _controller.startScanning(
        scanFrontFirst: _controller.selectedMode == DocumentTypeMode.nationalId,
      );
      if (_controller.selectedMode != DocumentTypeMode.nationalId) {
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _captureFront() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      HapticFeedback.mediumImpact();
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      final croppedBytes = await CardImageCropper.cropToCardFrame(bytes);
      _controller.onFrontCaptured(croppedBytes);
      _startImageStream();
    } catch (e) {
      debugPrint('Error capturing front photo: $e');
      _controller.skipFrontCapture();
      _startImageStream();
    }
  }

  void _skipFront() {
    _controller.skipFrontCapture();
    _startImageStream();
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isStreaming) return;

    _isStreaming = true;
    _cameraController!.startImageStream((CameraImage image) {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage != null) {
        _controller.onFrameCaptured(inputImage);
      }
    });
  }

  void _stopImageStream() {
    if (_cameraController != null && _isStreaming) {
      _isStreaming = false;
      _cameraController!.stopImageStream();
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = _orientations[camera.sensorOrientation];
      if (rotationCompensation == null) return null;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Concat all plane bytes into contiguous buffer
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static final Map<int, int> _orientations = {
    0: 0,
    90: 90,
    180: 180,
    270: 270,
  };

  Future<void> _onStateChanged() async {
    final state = _controller.state;

    if (state is IdReaderMrzCaptured) {
      HapticFeedback.heavyImpact();
      _stopImageStream();

      // Attempt capturing high-res photo of card back / passport page
      Uint8List? capturedPageBytes;
      try {
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          final backFile = await _cameraController!.takePicture();
          final backBytes = await backFile.readAsBytes();
          capturedPageBytes = await CardImageCropper.cropToCardFrame(backBytes);
          _controller.setBackCardBytes(capturedPageBytes);
        }
      } catch (_) {}

      // If regular passport mode, finish immediately with MRZ data & photo without NFC!
      if (_controller.selectedMode == DocumentTypeMode.regularPassport) {
        _controller.completeWithMrzOnly(
          state.mrzData,
          photoBytes: capturedPageBytes ?? _controller.frontCardBytes,
        );
        return;
      }

      if (mounted) {
        _showNfcModal(state);
      }
    } else if (state is IdReaderSuccess) {
      // Close bottom sheet if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      // Navigate to Details View
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IdDetailsView(
            idCard: state.idCard,
            targetEmployeeId: widget.targetEmployeeId,
            targetEmployeeName: widget.targetEmployeeName,
            auth: widget.auth,
          ),
        ),
      );
    } else if (state is IdReaderError) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showErrorDialog(state.failure.message);
    }
  }

  void _showNfcModal(IdReaderMrzCaptured state) {
    final isPassport = state.mrzData.isPassport ||
        _controller.selectedMode == DocumentTypeMode.electronicPassport;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final currentState = _controller.state;
            String step = isPassport
                ? 'ضع ظهر الهاتف على صفحة بيانات الجواز للمسح'
                : 'ضع ظهر البطاقة على ظهر الهاتف للمسح';
            double progress = 0.05;

            if (currentState is IdReaderNfcReading) {
              step = currentState.stepDescription;
              progress = currentState.progress;
            }

            return NfcTappingSheet(
              stepDescription: step,
              progress: progress,
              isPassport: isPassport,
              onCancel: () {
                Navigator.of(bottomSheetContext).pop();
                _controller.startScanning(
                  scanFrontFirst: _controller.selectedMode == DocumentTypeMode.nationalId,
                );
                _startImageStream();
              },
              onSkipNfc: () {
                Navigator.of(bottomSheetContext).pop();
                _controller.completeWithMrzOnly(state.mrzData);
              },
            );
          },
        );
      },
    );

    // Interrogate NFC microchip with both front and back photos attached
    _controller.startNfcReading(
      state.mrzData,
      frontCardBytes: _controller.frontCardBytes,
      backCardBytes: _controller.backCardBytes,
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('فشلت القراءة', style: TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFB0B7C3)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.startScanning(
                scanFrontFirst: _controller.selectedMode == DocumentTypeMode.nationalId,
              );
              if (_controller.selectedMode != DocumentTypeMode.nationalId) {
                _startImageStream();
              }
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isFront = _controller.state is IdReaderScanningFront;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Camera Live Preview
              CameraPreview(_cameraController!),

              // Guided Viewfinder Overlay with Front/Back switching
              MrzCameraOverlay(
                onBack: () => Navigator.of(context).pop(),
                onToggleFlash: _toggleFlash,
                isFlashOn: _isFlashOn,
                isFrontMode: isFront,
                onCaptureFront: _captureFront,
                onSkipFront: _skipFront,
                targetEmployeeName: widget.targetEmployeeName,
                documentMode: _controller.selectedMode,
                onModeChanged: (mode) {
                  _controller.setDocumentMode(mode);
                  if (mode != DocumentTypeMode.nationalId) {
                    _startImageStream();
                  } else {
                    _stopImageStream();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

