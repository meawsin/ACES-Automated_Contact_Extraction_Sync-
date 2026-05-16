// lib/screens/scanner_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/scan_record.dart';
import '../services/app_settings.dart';

enum ScanState { scanningFront, scanningBack, processing }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController?    _cameraController;
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  ScanState _currentState     = ScanState.scanningFront;
  bool      _isProcessingFrame = false;
  DateTime  _lastProcessedTime = DateTime.now();
  String    _frontCardText     = '';
  String    _backCardText      = '';
  int       _stabilityCounter  = 0;

  final ValueNotifier<String> _liveText =
      ValueNotifier<String>('Looking for text...');

  // Pulse animation for the scan frame
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  static const _teal = Color(0xFF00C2A8);
  static const _navy = Color(0xFF0D1B2A);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});
    _startContinuousScanning();
  }

  void _startContinuousScanning() {
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame || _currentState == ScanState.processing) return;

      final now = DateTime.now();
      if (now.difference(_lastProcessedTime).inMilliseconds < 500) return;

      _isProcessingFrame  = true;
      _lastProcessedTime  = now;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final imageSize  = Size(image.width.toDouble(), image.height.toDouble());
        final rotation   = InputImageRotationValue.fromRawValue(
                _cameraController!.description.sensorOrientation) ??
            InputImageRotation.rotation0deg;
        final format     = InputImageFormatValue.fromRawValue(image.format.raw) ??
            (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

        final metadata  = InputImageMetadata(
          size:         imageSize,
          rotation:     rotation,
          format:       format,
          bytesPerRow:  image.planes.first.bytesPerRow,
        );

        final inputImage     = InputImage.fromBytes(bytes: bytes, metadata: metadata);
        final recognizedText = await _textRecognizer.processImage(inputImage);

        if (mounted) {
          var preview = recognizedText.text.replaceAll('\n', ' ');
          if (preview.length > 50) preview = '${preview.substring(0, 50)}...';
          _liveText.value = preview.isNotEmpty ? preview : 'No text detected';
        }

        if (recognizedText.text.length > 40) {
          _stabilityCounter++;
          if (_stabilityCounter >= 3) {
            HapticFeedback.heavyImpact();
            if (_currentState == ScanState.scanningFront) {
              setState(() {
                _frontCardText    = recognizedText.text;
                _currentState     = ScanState.scanningBack;
                _stabilityCounter = 0;
              });
              _liveText.value = 'Flip to back of card…';
            } else if (_currentState == ScanState.scanningBack) {
              _backCardText = recognizedText.text;
              _finishScanning();
            }
          }
        } else {
          _stabilityCounter = 0;
        }
      } catch (_) {
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _finishScanning() async {
    setState(() => _currentState = ScanState.processing);
    _cameraController?.stopImageStream();

    final finalText = '$_frontCardText\n\n$_backCardText';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: _ProcessingOverlay(),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse(AppSettings.parseCardEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'raw_text': finalText}),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data       = jsonDecode(response.body)['data'] as Map<String, dynamic>;
        final scansBox   = Hive.box<ScanRecord>('scan_records');
        final newRecord  = ScanRecord(
          name:         data['Name']         as String? ?? 'Unknown Name',
          organization: data['Organisation'] as String? ?? '',
          designation:  data['Designation']  as String? ?? '',
          phone:        (data['Mobile'] as String?)?.isNotEmpty == true
                            ? data['Mobile'] as String
                            : (data['Telephone'] as String? ?? ''),
          email:        data['Email']        as String? ?? '',
          telephone:    data['Telephone']    as String? ?? '',
          fax:          data['FAX']          as String? ?? '',
          address:      data['Address']      as String? ?? '',
          links:        data['Links']        as String? ?? '',
          scannedAt:    DateTime.now(),
          isSynced:     false,
        );
        await scansBox.add(newRecord);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card scanned and saved!'),
            backgroundColor: Color(0xFF00875A),
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _liveText.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    final isFront   = _currentState == ScanState.scanningFront;
    final frameColor = isFront ? Colors.white : _teal;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width:  _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child:  CameraPreview(_cameraController!),
              ),
            ),
          ),

          // Dark vignette overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                radius: 1.0,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(isFront),

                const Spacer(),

                // Card frame with corner brackets
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _currentState == ScanState.processing ? 0.3 : 1.0,
                    child: _CardFrame(
                      color: frameColor,
                      pulseValue: _pulseAnim.value,
                    ),
                  ),
                ),

                const Spacer(),

                // Live text preview
                _buildLivePreview(),

                // Bottom action
                _buildBottomAction(isFront),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isFront) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFront ? 'Scan Front Side' : 'Scan Back Side',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  isFront ? 'Hold card steady inside the frame'
                           : 'Flip the card and hold steady',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          // Step indicator
          _StepIndicator(step: isFront ? 1 : 2),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.text_fields, color: _teal, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _liveText,
                builder: (_, value, __) => Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(bool isFront) {
    if (isFront) return const SizedBox(height: 54);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _finishScanning,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.skip_next, size: 20),
          label: const Text('Skip — Single Sided',
              style: TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

// ── Corner-bracket card frame ─────────────────────────────────────────────────

class _CardFrame extends StatelessWidget {
  final Color  color;
  final double pulseValue;
  const _CardFrame({required this.color, required this.pulseValue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 200,
      child: CustomPaint(
        painter: _CornerBracketPainter(color: color, opacity: pulseValue),
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color  color;
  final double opacity;
  const _CornerBracketPainter({required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color   = color.withValues(alpha: opacity)
      ..strokeWidth = 3
      ..style   = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 24.0; // bracket length

    // Top-left
    canvas.drawLine(Offset(0, corner), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(corner, 0), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - corner, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, corner), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height - corner), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(corner, size.height), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - corner, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - corner), paint);

    // Subtle full-frame dim rect
    final dimPaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) =>
      old.color != color || old.opacity != opacity;
}

// ── Step indicator (1/2) ──────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$step / 2',
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Processing overlay ────────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(48),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00C2A8), strokeWidth: 3),
          const SizedBox(height: 18),
          const Text('Parsing card…',
              style: TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('AI is extracting contact details',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }
}