import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ResultScreen extends StatefulWidget {
  // --- ADDED: originalVideoUrl parameter ---
  final String? originalVideoUrl; // Nullable in case backend doesn't send it
  // ---
  final List<String> clipUrls;
  final String summaryUrl;
  final List<String> groundTruthUrls;

  const ResultScreen({
    Key? key,
    // --- ADDED: required originalVideoUrl ---
    required this.originalVideoUrl,
    // ---
    required this.clipUrls,
    required this.summaryUrl,
    required this.groundTruthUrls,
  }) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  // --- ADDED: Controller for the original video ---
  VideoPlayerController? _originalController;
  // ---
  final List<VideoPlayerController> _clipControllers = []; // Renamed for clarity
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeAllVideos(); // Renamed init function
  }

  @override
  void dispose() {
    // --- ADDED: Dispose original controller ---
    _originalController?.dispose();
    // ---
    for (var c in _clipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- REVISED: Initialize original video and clips ---
  Future<void> _initializeAllVideos() async {
    final dir = await getTemporaryDirectory();

    // Initialize Original Video (if URL exists)
    if (widget.originalVideoUrl != null) {
      _originalController = await _downloadAndInitializeVideo(widget.originalVideoUrl!, dir);
    }

    // Initialize Clip Videos
    for (var url in widget.clipUrls) {
      final controller = await _downloadAndInitializeVideo(url, dir);
      if (controller != null) {
        _clipControllers.add(controller);
      }
    }

    // Call setState after all controllers are processed
    if (mounted) {
      setState(() {});
    }
  }

  // --- ADDED: Helper function for download & initialization ---
  Future<VideoPlayerController?> _downloadAndInitializeVideo(String url, Directory dir) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        print('Failed to download video from $url: Status ${resp.statusCode}');
        return null; // Return null on failure
      }
      final filename = Uri.parse(url).pathSegments.last; // Safer way to get filename
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(resp.bodyBytes);

      // Use file constructor for local files
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      return controller;
    } catch (e) {
      print('Error downloading or initializing video from $url: $e');
      return null; // Return null on error
    }
  }
  // ---

  // Keep the summary fetching logic as is
  Future<String> _fetchSummary() async {
    try {
      final resp = await http.get(Uri.parse(widget.summaryUrl));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['response'] ?? 'No summary available.';
      } else {
        print('Failed to load summary from ${widget.summaryUrl}: Status ${resp.statusCode}');
        return 'Failed to load summary. Status code: ${resp.statusCode}';
      }
    } catch (e) {
      print('Error fetching summary from ${widget.summaryUrl}: $e');
      return 'Error fetching summary: $e';
    }
  }

  // --- ADDED: Helper to build video player widget ---
  Widget _buildVideoPlayerUI(VideoPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          });
        },
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              // Optional: Add a play/pause icon overlay when paused
              if (!controller.value.isPlaying)
                Container(
                  color: Colors.black26,
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  // ---

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
            }
            if (snap.hasError) {
              // More general error message
              return Center(child: Text('Error initializing resources: ${snap.error}', style: const TextStyle(color: Colors.red)));
            }
            // Check if at least one video (original or clip) was loaded
            if (_originalController == null && _clipControllers.isEmpty) {
              return const Center(child: Text('No videos were processed or downloaded.', style: TextStyle(color: Colors.black87)));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ADDED: Display Original Video ---
                  if (_originalController != null && _originalController!.value.isInitialized) ...[
                    Text('Original Video:', style: textTheme.titleMedium?.copyWith(color: Colors.black87)),
                    _buildVideoPlayerUI(_originalController!), // Use helper
                    const SizedBox(height: 24), // Add spacing
                    const Divider(), // Add a visual separator
                    const SizedBox(height: 24), // Add spacing
                  ],
                  // ---

                  // --- MODIFIED: Display Clips ---
                  if (_clipControllers.isNotEmpty) ...[
                    Text('Abnormal Clips:', style: textTheme.titleMedium?.copyWith(color: Colors.black87)),
                    ..._clipControllers.map((c) => _buildVideoPlayerUI(c)).toList(), // Use helper
                    const SizedBox(height: 24),
                  ],
                  // ---

                  // Ground-truth images (keep as is, but add separator)
                  if (widget.groundTruthUrls.isNotEmpty) ... [
                    const Divider(),
                    const SizedBox(height: 24),
                    Text('Ground Truth:', style: textTheme.titleMedium?.copyWith(color: Colors.black87)),
                    ...widget.groundTruthUrls.map((url) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Image.network(
                          url,
                          errorBuilder: (context, error, stackTrace) =>
                          const Text('Failed to load image', style: TextStyle(color: Colors.red)),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: Colors.deepPurple,
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],

                  // Summary (keep as is, but add separator)
                  const Divider(),
                  const SizedBox(height: 24),
                  Text('Summary:', style: textTheme.titleMedium?.copyWith(color: Colors.black87)),
                  FutureBuilder<String>(
                    future: _fetchSummary(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
                      } else if (snap.hasError) {
                        return Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red));
                      } else if (snap.hasData && snap.data!.isNotEmpty) { // Check if data exists and is not empty
                        return Text(snap.data!, style: const TextStyle(color: Colors.black87));
                      } else {
                        return const Text('No summary available.', style: TextStyle(color: Colors.black87)); // Handle empty summary case
                      }
                    },
                  ),
                  const SizedBox(height: 24), // Add padding at the bottom
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}