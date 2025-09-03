import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';
import 'package:pro_capcut/presentation/widgets/ai_processing_animation.dart';

class ProcessingOverlay extends StatelessWidget {
  final EditorProcessing processingState;
  const ProcessingOverlay({super.key, required this.processingState});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: (processingState.type == ProcessingType.aiEnhance)
              ? const AiProcessingAnimation()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Card(
                    color: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Processing... ${(processingState.progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: processingState.progress,
                            backgroundColor: Colors.grey[800],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
