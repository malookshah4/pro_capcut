// lib/presentation/widgets/export_options_sheet.dart
import 'package:flutter/material.dart';

// A simple data class to hold the selected export settings
class ExportSettings {
  final int resolution;
  final int frameRate;
  final double codeRate;

  ExportSettings({
    required this.resolution,
    required this.frameRate,
    required this.codeRate,
  });
}

class ExportOptionsSheet extends StatefulWidget {
  const ExportOptionsSheet({super.key});

  @override
  State<ExportOptionsSheet> createState() => _ExportOptionsSheetState();
}

class _ExportOptionsSheetState extends State<ExportOptionsSheet> {
  double _resolutionValue = 1080;
  double _frameRateValue = 30;
  double _codeRateValue = 1.0; // 0=Low, 1=Recommended, 2=High

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF222222),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOptionRow(
            'Resolution',
            '${_resolutionValue.toInt()}p',
            Slider(
              value: _resolutionValue,
              min: 480,
              max: 1080,
              divisions: 2, // (480, 720, 1080)
              label: '${_resolutionValue.toInt()}p',
              onChanged: (value) => setState(() => _resolutionValue = value),
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.white30,
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionRow(
            'Frame rate',
            '${_frameRateValue.toInt()}',
            Slider(
              value: _frameRateValue,
              min: 24,
              max: 60,
              divisions: 36,
              label: '${_frameRateValue.toInt()}',
              onChanged: (value) => setState(() => _frameRateValue = value),
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.white30,
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionRow(
            'Code rate (Mbps)',
            _getCodeRateLabel(_codeRateValue),
            Slider(
              value: _codeRateValue,
              min: 0,
              max: 2,
              divisions: 2,
              label: _getCodeRateLabel(_codeRateValue),
              onChanged: (value) => setState(() => _codeRateValue = value),
              activeColor: Colors.blueAccent,
              inactiveColor: Colors.white30,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final settings = ExportSettings(
                  resolution: _resolutionValue.toInt(),
                  frameRate: _frameRateValue.toInt(),
                  codeRate: _codeRateValue,
                );
                // Return the settings when popping the sheet
                Navigator.pop(context, settings);
              },
              icon: const Icon(Icons.file_download_done_rounded),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String title, String value, Widget control) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        control,
      ],
    );
  }

  String _getCodeRateLabel(double value) {
    if (value == 0) return 'Low';
    if (value == 1) return 'Recommended';
    return 'High';
  }
}
