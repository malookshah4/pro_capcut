import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Volume',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                '${(_currentVolume * 100).toInt()}', // Display volume as percentage
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
          Slider(
            value: _currentVolume,
            min: 0.0, // 0% volume (mute)
            max: 2.0, // 200% volume (boost)
            label: '${(_currentVolume * 100).toInt()}',
            activeColor: Colors.white,
            inactiveColor: Colors.white30,
            onChanged: (value) {
              setState(() {
                _currentVolume = value;
              });
              // You can dispatch here for live updates, but it can be janky.
              // It's often better to dispatch only when the user finishes dragging.
            },
            // ✨ This is the best place to update the BLoC state
            onChangeEnd: (value) {
              context.read<EditorBloc>().add(ClipVolumeChanged(value));
            },
          ),
        ],
      ),
    );
  }
}
