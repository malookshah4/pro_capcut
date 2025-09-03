import 'package:flutter/material.dart';

class SpeedControlSheet extends StatefulWidget {
  final double initialSpeed;
  final Duration originalDuration;

  const SpeedControlSheet({
    super.key,
    required this.initialSpeed,
    required this.originalDuration,
  });

  @override
  State<SpeedControlSheet> createState() => _SpeedControlSheetState();
}

class _SpeedControlSheetState extends State<SpeedControlSheet> {
  late double _currentSpeed;
  final List<double> _speedOptions = [0.2, 0.5, 1.0, 1.5, 2.0, 5.0];

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.initialSpeed;
  }

  String _formatDuration(Duration d) {
    return d.inSeconds.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final newDuration = Duration(
      microseconds: (widget.originalDuration.inMicroseconds / _currentSpeed)
          .round(),
    );

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
          // Header with duration and cancel/confirm buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () =>
                    Navigator.pop(context), // Dismiss without a value
              ),
              Column(
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(widget.originalDuration)}s → ${_formatDuration(newDuration)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.check,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(
                  context,
                  _currentSpeed,
                ), // Return the selected speed
              ),
            ],
          ),
          const SizedBox(height: 20),
          // The speed selection slider-like UI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _speedOptions.map((speed) {
              final bool isSelected = _currentSpeed == speed;
              return GestureDetector(
                onTap: () => setState(() => _currentSpeed = speed),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${speed}x',
                      style: TextStyle(
                        color: isSelected ? Colors.blueAccent : Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: isSelected ? 20 : 10,
                      width: 2.5,
                      color: isSelected ? Colors.blueAccent : Colors.white54,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
