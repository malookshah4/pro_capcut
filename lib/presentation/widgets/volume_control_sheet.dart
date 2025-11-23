import 'package:flutter/material.dart';

class VolumeControlSheet extends StatefulWidget {
  final double initialVolume;
  const VolumeControlSheet({super.key, required this.initialVolume});

  @override
  State<VolumeControlSheet> createState() => _VolumeControlSheetState();
}

class _VolumeControlSheetState extends State<VolumeControlSheet> {
  late double _currentVolume;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.initialVolume;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 22, 22, 22),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // --- HEADER: Title & Actions ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close (Cancel)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),

              // Title & Value
              Column(
                children: [
                  const Text(
                    'Volume',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_currentVolume * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Check (Confirm) -- THIS WAS MISSING
              IconButton(
                icon: const Icon(
                  Icons.check,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context, _currentVolume),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // --- SLIDER ---
          Slider(
            value: _currentVolume,
            min: 0.0, // 0% (Mute)
            max: 2.0, // 200% (Boost)
            divisions: 200,
            label: '${(_currentVolume * 100).toInt()}%',
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white30,
            onChanged: (value) {
              setState(() {
                _currentVolume = value;
              });
            },
          ),
        ],
      ),
    );
  }
}
