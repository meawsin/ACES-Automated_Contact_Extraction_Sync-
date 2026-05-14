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

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  ScanState _currentState = ScanState.scanningFront;
  bool _isProcessingFrame = false;
  
  DateTime _lastProcessedTime = DateTime.now();
  String _frontCardText = "";
  String _backCardText = "";
  int _stabilityCounter = 0;

  // 1. REPLACED String WITH ValueNotifier
  // This allows us to update the text on screen without rebuilding the camera preview!
  final ValueNotifier<String> _liveTextPreview = ValueNotifier<String>("Looking for text...");

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() {});
    _startContinuousScanning();
  }

  void _startContinuousScanning() {
    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame || _currentState == ScanState.processing) return;
      
      // --- NEW: THE THROTTLE ---
      // Only run ML Kit once every 500 milliseconds (2 times a second)
      final now = DateTime.now();
      if (now.difference(_lastProcessedTime).inMilliseconds < 500) {
        return; // Skip this frame, let the camera render!
      }
      
      _isProcessingFrame = true;
      _lastProcessedTime = now; // Update the clock

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
        final imageRotation = InputImageRotationValue.fromRawValue(_cameraController!.description.sensorOrientation) ?? InputImageRotation.rotation0deg;
        final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? 
                       (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

        final inputImageData = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
        
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        if (mounted) {
          String previewString = recognizedText.text.replaceAll('\n', ' ');
          if (previewString.length > 50) {
            previewString = '${previewString.substring(0, 50)}...';
          }
          _liveTextPreview.value = previewString; 
        }

        // --- Stability & Focus Logic ---
        if (recognizedText.text.length > 40) { 
          _stabilityCounter++;
          
          // Reduced requirement from 5 to 3 since we are scanning slower now
          if (_stabilityCounter >= 3) { 
            HapticFeedback.heavyImpact(); 
            
            if (_currentState == ScanState.scanningFront) {
              setState(() {
                _frontCardText = recognizedText.text;
                _currentState = ScanState.scanningBack; 
                _stabilityCounter = 0; 
              });
              _liveTextPreview.value = "Flip to Back..."; 
            } else if (_currentState == ScanState.scanningBack) {
              _backCardText = recognizedText.text;
              _finishScanning();
            }
          }
        } else {
          _stabilityCounter = 0; 
        }
      } catch (e) {
        print("ML KIT ERROR: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
  }


  Future<void> _finishScanning() async {
    setState(() => _currentState = ScanState.processing);
    _cameraController?.stopImageStream();
    
    String finalText = "$_frontCardText\n\n$_backCardText";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
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
        final responseData = jsonDecode(response.body);
        final parsedData = responseData['data'];

        final scansBox = Hive.box<ScanRecord>('scan_records'); // Make sure this name matches main.dart!
        final newRecord = ScanRecord(
          name: parsedData['Name'] ?? 'Unknown Name',
          organization: parsedData['Organisation'] ?? 'Unknown Org',
          designation: parsedData['Designation'] ?? 'Unknown Title',
          phone: parsedData['Mobile'] ?? parsedData['Telephone'] ?? 'No Phone', 
          email: parsedData['Email'] ?? 'No Email',
          scannedAt: DateTime.now(),
          isSynced: false, 
        );
        
        await scansBox.add(newRecord);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card parsed and saved locally!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 

      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network Error: $e'), backgroundColor: Colors.red),
      );
      Navigator.pop(context); 
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _liveTextPreview.dispose(); // 3. Dispose the notifier to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(
                    _currentState == ScanState.scanningFront 
                        ? "Align Front of Card" 
                        : "Align Back of Card",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),

                Container(
                  height: 250,
                  width: 350,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _currentState == ScanState.scanningBack ? Colors.green : Colors.white, 
                      width: 3
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                
                // 4. UPDATED: Wrapped the Text in a ValueListenableBuilder
                // Now, ONLY this text widget redraws when ML kit finds new text.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _liveTextPreview,
                    builder: (context, value, child) {
                      return Text(
                        value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.yellow, fontSize: 14),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _currentState == ScanState.scanningBack 
                    ? ElevatedButton.icon(
                        onPressed: _finishScanning,
                        icon: const Icon(Icons.skip_next),
                        label: const Text("Skip - Single Sided"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : const SizedBox(height: 48), 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}