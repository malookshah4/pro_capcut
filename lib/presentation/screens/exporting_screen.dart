import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pro_capcut/bloc/editor_bloc.dart';

class ExportingScreen extends StatefulWidget {
  final EditorLoaded processingState;
  final String?
  thumbnailPath; // Pass the thumbnail path here instead of controller

  const ExportingScreen({
    super.key,
    required this.processingState,
    this.thumbnailPath,
  });

  @override
  State<ExportingScreen> createState() => _ExportingScreenState();
}

class _ExportingScreenState extends State<ExportingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Setup a subtle breathing animation for the thumbnail
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getStatusText(double progress) {
    if (progress <= 0.0) return "Preparing assets...";
    if (progress < 0.2) return "Processing video clips...";
    if (progress < 0.5) return "Applying effects & overlays...";
    if (progress < 0.8) return "Merging audio tracks...";
    if (progress < 0.99) return "Encoding final video...";
    return "Finalizing...";
  }

  @override
  Widget build(BuildContext context) {
    // Safely clamp progress between 0.0 and 1.0
    final progressValue = widget.processingState.processingProgress.clamp(
      0.0,
      1.0,
    );
    final percentage = (progressValue * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Deep dark background
      body: Stack(
        children: [
          // Background Blur Effect
          if (widget.thumbnailPath != null)
            Positioned.fill(
              child: Image.file(
                File(widget.thumbnailPath!),
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.2),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Thumbnail Container
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 180,
                      height: 320, // 9:16 aspect ratio look
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(
                              0.3 * progressValue,
                            ),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: widget.thumbnailPath != null
                            ? Image.file(
                                File(widget.thumbnailPath!),
                                fit: BoxFit.cover,
                                // ADD THESE LINES:
                                cacheWidth:
                                    300, // Limit memory usage for the image
                                gaplessPlayback: true,
                              )
                            : Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.white24,
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Percentage Text
                  Text(
                    "$percentage%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      fontFamily: 'monospace', // Tech look
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Bar
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: constraints.maxWidth * progressValue,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00C6FF,
                                  ).withOpacity(0.6),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Dynamic Status Text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _getStatusText(progressValue),
                      key: ValueKey<String>(_getStatusText(progressValue)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Keep the app open",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),

                  const Spacer(flex: 3),

                  // Cancel Button
                  TextButton(
                    onPressed: () {
                      // Add logic to cancel export in your Bloc
                      // context.read<EditorBloc>().add(ExportCancelled());
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white30),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
