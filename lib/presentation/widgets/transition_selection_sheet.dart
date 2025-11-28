import 'package:flutter/material.dart';

class TransitionSelectionSheet extends StatefulWidget {
  final String? currentType;
  final Duration currentDuration;

  const TransitionSelectionSheet({
    super.key,
    this.currentType,
    required this.currentDuration,
  });

  @override
  State<TransitionSelectionSheet> createState() =>
      _TransitionSelectionSheetState();
}

class _TransitionSelectionSheetState extends State<TransitionSelectionSheet> {
  late String? _selectedType;
  late double _durationSeconds;

  final List<Map<String, dynamic>> _transitions = [
    {'id': null, 'name': 'None', 'icon': Icons.block},
    {'id': 'fade', 'name': 'Mix', 'icon': Icons.blur_on},
    {'id': 'slideleft', 'name': 'Slide L', 'icon': Icons.west},
    {'id': 'slideright', 'name': 'Slide R', 'icon': Icons.east},
    {'id': 'wipeleft', 'name': 'Wipe', 'icon': Icons.cleaning_services},
    {
      'id': 'circleopen',
      'name': 'Circle',
      'icon': Icons.radio_button_unchecked,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
    _durationSeconds = widget.currentDuration.inMilliseconds / 1000.0;
    if (_durationSeconds == 0) _durationSeconds = 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Transitions",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.blueAccent),
                  onPressed: () {
                    Navigator.pop(context, {
                      'type': _selectedType,
                      'duration': Duration(
                        milliseconds: (_durationSeconds * 1000).toInt(),
                      ),
                    });
                  },
                ),
              ],
            ),
          ),

          // Slider
          if (_selectedType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Text(
                    "Duration",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Expanded(
                    child: Slider(
                      value: _durationSeconds,
                      min: 0.1,
                      max: 2.0,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) =>
                          setState(() => _durationSeconds = val),
                    ),
                  ),
                  Text(
                    "${_durationSeconds.toStringAsFixed(1)}s",
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _transitions.length,
              itemBuilder: (context, index) {
                final t = _transitions[index];
                final isSelected = _selectedType == t['id'];

                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t['id']),
                  child: Column(
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Icon(t['icon'], color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['name'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
