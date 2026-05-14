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
  
  String _frontCardText = "";
  String _backCardText = "";
  String _liveTextPreview = "Looking for text...";
  int _stabilityCounter = 0;

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
      // --- THIS IS THE MAGIC FIX ---
      // Force Android to use NV21 and iOS to use BGRA8888
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
        _isProcessingFrame = true;

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

          // --- NEW: Visual Debugging ---
          if (mounted) {
            setState(() {
              // Show the first 50 chars of whatever it sees
              _liveTextPreview = recognizedText.text.replaceAll('\n', ' ');
              if (_liveTextPreview.length > 50) {
                _liveTextPreview = '${_liveTextPreview.substring(0, 50)}...';
              }
            });
          }
          // -----------------------------

          // --- NEW: Stability & Focus Logic ---
        // A standard visiting card has roughly 50-100 characters. 
        if (recognizedText.text.length > 40) { 
          _stabilityCounter++;
          
          // Require 5 consecutive frames of good text (approx 1-1.5 seconds of holding still)
          if (_stabilityCounter >= 5) {
            HapticFeedback.heavyImpact(); 
            
            if (_currentState == ScanState.scanningFront) {
              setState(() {
                _frontCardText = recognizedText.text;
                _currentState = ScanState.scanningBack; 
                _stabilityCounter = 0; // Reset for the back card
                _liveTextPreview = "Flip to Back...";
              });
            } else if (_currentState == ScanState.scanningBack) {
              _backCardText = recognizedText.text;
              _finishScanning();
            }
          }
        } else {
          // If the camera moves or gets blurry, reset the counter
          _stabilityCounter = 0; 
        }
        // ------------------------------------
        } catch (e) {
          // --- NEW: Expose the Error ---
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
    
    // Show a loading dialog while talking to Laravel
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Send the raw text to your Laravel API
      final response = await http.post(
        Uri.parse('http://192.168.68.135:8000/api/parse-card'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'raw_text': finalText}),
      );

      // Dismiss the loading indicator
      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final parsedData = responseData['data'];

        // 2. Save the AI's structured data into our local Hive Database
        final scansBox = Hive.box<ScanRecord>('scansBox');
        final newRecord = ScanRecord(
          name: parsedData['Name'] ?? 'Unknown Name',
          organization: parsedData['Organisation'] ?? 'Unknown Org',
          designation: parsedData['Designation'] ?? 'Unknown Title',
          phone: parsedData['Mobile'] ?? parsedData['Telephone'] ?? 'No Phone', // Fallback to Telephone if Mobile is null
          email: parsedData['Email'] ?? 'No Email',
          scannedAt: DateTime.now(),
          isSynced: false, 
        );
        
        await scansBox.add(newRecord);

        // 3. Go back to Home Screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card parsed and saved locally!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 

      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network Error: $e'), backgroundColor: Colors.red),
      );
      Navigator.pop(context); // Go back to Home Screen
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
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
          // Camera Feed with Aspect Ratio Fix
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // We swap height and width here because camera sensors are natively landscape, 
                // but your phone is being held in portrait mode.
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),

          // UI Overlay
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Instruction Text
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

                // Center Bounding Box (Visual Guide)
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
                
                // --- NEW: Live Text Preview ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    _liveTextPreview,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.yellow, fontSize: 14),
                  ),
                ),

                // Bottom Controls (Skip Button)
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
                    : const SizedBox(height: 48), // Empty space to keep layout balanced
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}