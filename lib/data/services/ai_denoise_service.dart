// lib/data/services/ai_denoise_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AiDenoiseService {
  Interpreter? _interpreter1;
  Interpreter? _interpreter2;

  late List<List<List<List<double>>>> _states1;
  late List<List<List<List<double>>>> _states2;

  static const int _sampleRate = 16000;
  static const int _frameSize = 512;
  static const int _hopSize = 128;
  // static const int _fftSize = 512;
  static const int _numBins = 257; // FFT size/2 + 1

  bool _modelsLoaded = false;
  final List<double> _hannWindow = [];
  final List<double> _noiseProfile = [];
  final double _noiseFloor = 0.01;
  double _prevVadProbability = 0.0;

  Future<void> _loadModels() async {
    if (_modelsLoaded) return;

    // Initialize Hann window
    for (int i = 0; i < _frameSize; i++) {
      _hannWindow.add(0.5 * (1 - cos(2 * pi * i / (_frameSize - 1))));
    }

    try {
      _interpreter1 = await Interpreter.fromAsset(
        'assets/models/model_quant_1.tflite',
      );
      _interpreter2 = await Interpreter.fromAsset(
        'assets/models/model_quant_2.tflite',
      );

      // Initialize states with correct shapes
      _states1 = List.generate(
        1,
        (_) => List.generate(
          2,
          (_) => List.generate(128, (_) => List.filled(2, 0.0)),
        ),
      );

      _states2 = List.generate(
        1,
        (_) => List.generate(
          2,
          (_) => List.generate(128, (_) => List.filled(2, 0.0)),
        ),
      );

      // Initialize noise profile
      _noiseProfile.addAll(List.filled(_numBins, 0.0));

      _modelsLoaded = true;
      print('DTLN TFLite models loaded successfully.');
    } catch (e) {
      print('Failed to load TFLite models: $e');
    }
  }

  Future<String?> processAudioFile(String inputPath) async {
    await _loadModels();
    if (!_modelsLoaded) return null;

    // Reset states
    _resetStates();

    try {
      final inputFile = File(inputPath);
      final inputBytes = await inputFile.readAsBytes();
      final audioSamples = inputBytes.buffer.asInt16List(44);

      final List<double> cleanSamples = List.filled(audioSamples.length, 0.0);
      final List<double> overlapBuffer = List.filled(_frameSize, 0.0);

      // First pass: learn noise profile from first few frames
      bool noiseProfileLearned = false;
      int noiseLearningFrames = min(10, audioSamples.length ~/ _frameSize);

      for (int i = 0; i + _frameSize <= audioSamples.length; i += _hopSize) {
        // Extract and window frame
        final frame = Float32List(_frameSize);
        for (int j = 0; j < _frameSize; j++) {
          frame[j] = (audioSamples[i + j] / 32768.0) * _hannWindow[j];
        }

        // Learn noise profile from first few silent frames
        if (!noiseProfileLearned && i < noiseLearningFrames * _hopSize) {
          _updateNoiseProfile(frame);
          if (i >= (noiseLearningFrames - 1) * _hopSize) {
            noiseProfileLearned = true;
          }
          continue;
        }

        // Compute magnitude spectrum
        final magnitudeSpectrum = _computeMagnitudeSpectrum(frame);

        // Calculate voice activity probability
        final vadProbability = _calculateVadProbability(
          magnitudeSpectrum,
          frame,
        );

        // Prepare inputs and outputs for model 1
        final input1 = [
          [magnitudeSpectrum], // Shape: [1, 1, 257]
          _states1,
        ];

        final output1Mask = List.generate(
          1,
          (_) => List.generate(1, (_) => List.filled(_numBins, 0.0)),
        );

        final output1 = {0: output1Mask, 1: _states1};

        _interpreter1!.runForMultipleInputs(input1, output1);

        // Prepare inputs and outputs for model 2
        final input2 = [
          [frame], // Shape: [1, 1, 512]
          _states2,
        ];

        final output2Enhanced = List.generate(
          1,
          (_) => List.generate(1, (_) => List.filled(_frameSize, 0.0)),
        );

        final output2 = {0: output2Enhanced, 1: _states2};

        _interpreter2!.runForMultipleInputs(input2, output2);

        // Extract the enhanced frame
        final enhancedFrame = output2Enhanced[0][0];

        // Apply adaptive noise reduction based on VAD
        final processedFrame = _adaptiveNoiseReduction(
          enhancedFrame,
          frame,
          vadProbability,
        );

        // Apply window and overlap-add with crossfade
        for (int j = 0; j < _frameSize; j++) {
          final windowedSample = processedFrame[j] * _hannWindow[j];

          // Overlap-add with crossfade
          if (j < _hopSize) {
            final crossfade = j / _hopSize;
            cleanSamples[i + j] +=
                windowedSample * crossfade + overlapBuffer[j] * (1 - crossfade);
          } else {
            cleanSamples[i + j] += windowedSample;
          }

          // Store for next overlap
          if (j >= _frameSize - _hopSize) {
            final overlapIndex = j - (_frameSize - _hopSize);
            overlapBuffer[overlapIndex] = windowedSample;
          }
        }

        _prevVadProbability = vadProbability;
      }

      // Convert to Int16 and write WAV file
      final int16Samples = Int16List.fromList(
        cleanSamples
            .map((s) => (s * 32768.0).clamp(-32768, 32767).toInt())
            .toList(),
      );

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputPath = p.join(appDirectory.path, 'ai_clean_audio.wav');
      await _writeWav(outputPath, int16Samples, _sampleRate, 1);

      return outputPath;
    } catch (e) {
      print('Error during DTLN audio processing: $e');
      return null;
    }
  }

  void _updateNoiseProfile(List<double> frame) {
    final magnitudeSpectrum = _computeMagnitudeSpectrum(frame);
    final energy =
        magnitudeSpectrum.reduce((a, b) => a + b) / magnitudeSpectrum.length;

    // Only update noise profile if frame energy is below threshold (likely noise)
    if (energy < _noiseFloor * 2) {
      for (int i = 0; i < _numBins; i++) {
        _noiseProfile[i] = 0.9 * _noiseProfile[i] + 0.1 * magnitudeSpectrum[i];
      }
    }
  }

  double _calculateVadProbability(
    List<double> magnitudeSpectrum,
    List<double> frame,
  ) {
    // Calculate frame energy
    final energy =
        magnitudeSpectrum.reduce((a, b) => a + b) / magnitudeSpectrum.length;

    // Calculate spectral contrast (helps distinguish speech from noise)
    double spectralContrast = 0.0;
    magnitudeSpectrum.sort();
    final q3 = magnitudeSpectrum[(3 * magnitudeSpectrum.length ~/ 4)];
    final q1 = magnitudeSpectrum[magnitudeSpectrum.length ~/ 4];
    spectralContrast = q3 - q1;

    // Calculate zero-crossing rate (higher for speech)
    int zeroCrossings = 0;
    for (int i = 1; i < frame.length; i++) {
      if (frame[i] * frame[i - 1] < 0) zeroCrossings++;
    }
    final zcr = zeroCrossings / frame.length;

    // Combined VAD probability
    double vadProb = 0.0;

    // Energy-based detection
    final energyProb = min(
      1.0,
      max(0.0, (energy - _noiseFloor) / (_noiseFloor * 10)),
    );

    // Spectral contrast-based detection
    final contrastProb = min(1.0, max(0.0, spectralContrast / 0.1));

    // Zero-crossing rate-based detection
    final zcrProb = min(1.0, max(0.0, (zcr - 0.1) / 0.2));

    // Combine probabilities with weights
    vadProb = 0.6 * energyProb + 0.3 * contrastProb + 0.1 * zcrProb;

    // Apply temporal smoothing
    vadProb = 0.8 * _prevVadProbability + 0.2 * vadProb;

    return vadProb.clamp(0.0, 1.0);
  }

  List<double> _adaptiveNoiseReduction(
    List<double> enhancedFrame,
    List<double> originalFrame,
    double vadProbability,
  ) {
    final processedFrame = List<double>.filled(enhancedFrame.length, 0.0);

    // More aggressive noise reduction when speech is not detected
    final noiseReductionStrength = 0.3 + 0.7 * (1 - vadProbability);

    for (int i = 0; i < enhancedFrame.length; i++) {
      // Use more of the enhanced frame when speech is detected
      // Use more of the original frame when speech is not detected
      final enhancedWeight = 0.7 + 0.3 * vadProbability;
      final originalWeight = 1.0 - enhancedWeight;

      processedFrame[i] =
          enhancedFrame[i] * enhancedWeight + originalFrame[i] * originalWeight;

      // Apply additional noise reduction based on VAD probability
      if (vadProbability < 0.3) {
        // More aggressive noise reduction for non-speech frames
        processedFrame[i] *= (1 - noiseReductionStrength);
      }
    }

    return processedFrame;
  }

  List<double> _computeMagnitudeSpectrum(List<double> frame) {
    final int n = frame.length;
    final List<double> magnitude = List.filled(_numBins, 0.0);

    for (int k = 0; k < _numBins; k++) {
      double real = 0.0;
      double imag = 0.0;

      for (int t = 0; t < n; t++) {
        final double angle = 2 * pi * k * t / n;
        real += frame[t] * cos(angle);
        imag -= frame[t] * sin(angle);
      }

      magnitude[k] = sqrt(real * real + imag * imag);
    }

    return magnitude;
  }

  void _resetStates() {
    for (var i = 0; i < _states1.length; i++) {
      for (var j = 0; j < _states1[i].length; j++) {
        for (var k = 0; k < _states1[i][j].length; k++) {
          for (var l = 0; l < _states1[i][j][k].length; l++) {
            _states1[i][j][k][l] = 0.0;
          }
        }
      }
    }

    for (var i = 0; i < _states2.length; i++) {
      for (var j = 0; j < _states2[i].length; j++) {
        for (var k = 0; k < _states2[i][j].length; k++) {
          for (var l = 0; l < _states2[i][j][k].length; l++) {
            _states2[i][j][k][l] = 0.0;
          }
        }
      }
    }

    // Reset noise profile and VAD state
    for (int i = 0; i < _noiseProfile.length; i++) {
      _noiseProfile[i] = 0.0;
    }
    _prevVadProbability = 0.0;
  }

  Future<void> _writeWav(
    String path,
    Int16List samples,
    int sampleRate,
    int numChannels,
  ) async {
    final file = File(path);
    final byteData = ByteData(44 + samples.lengthInBytes);

    // Write WAV header
    byteData.setUint32(0, 0x46464952, Endian.little); // "RIFF"
    byteData.setUint32(4, 36 + samples.lengthInBytes, Endian.little);
    byteData.setUint32(8, 0x45564157, Endian.little); // "WAVE"
    byteData.setUint32(12, 0x20746d66, Endian.little); // "fmt "
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * numChannels * 2, Endian.little);
    byteData.setUint16(32, numChannels * 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    byteData.setUint32(36, 0x61746164, Endian.little); // "data"
    byteData.setUint32(40, samples.lengthInBytes, Endian.little);

    // Write audio data
    for (var i = 0; i < samples.length; i++) {
      byteData.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    await file.writeAsBytes(byteData.buffer.asUint8List());
  }
}
