import 'dart:convert'; // Keep this import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'ResultScreen.dart'; // Keep this import
import 'loginScreen.dart'; // Keep this import
import 'profile_screen.dart'; // Keep this import

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? userEmail;
  final _picker = ImagePicker();
  static const _backendUrl = 'http://192.168.36.155:8000'; // Keep the backend URL

  // State variable to track if video processing is happening
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _getUserEmail();
  }

  // Function to get user email from Firebase
  Future<void> _getUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if the widget is mounted before calling setState
      if (mounted) {
        setState(() {
          userEmail = user.email;
        });
      }
    }
  }

  // Keep the core video picking and processing logic
  Future<void> _pickVideoFromGallery() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    // --- Show Processing Animation ---
    if (mounted) {
      setState(() {
        _isProcessing = true; // Start the animation
      });
    }

    final uri = Uri.parse("$_backendUrl/process_video/");
    final req = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('IN_VIDEO', file.path));

    try {
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);


      if (mounted) {
        setState(() {
          _isProcessing = false; // Stop animation regardless of outcome below
        });
      }


      if (resp.statusCode == 200) {
        final raw = jsonDecode(resp.body);

        // --- ADDED: Extract original video filename ---
        final originalFilename = raw['original_video'] as String?; // Make nullable for safety
        // ---

        final clipsFilenames = List<String>.from(raw['clips']);
        final gtFilenames    = List<String>.from(raw['ground_truth_files']);

        // Construct URLs
        final clipUrls = clipsFilenames.map((f) => '$_backendUrl/clips/$f').toList();
        final gtUrls   = gtFilenames.map((f) => '$_backendUrl/groundtruth/$f').toList();
        final summaryUrl = '$_backendUrl/summaries'; // This might need adjustment based on actual backend

        // --- ADDED: Construct original video URL (handle potential null) ---
        final String? originalVideoUrl = originalFilename != null
            ? '$_backendUrl/originals/$originalFilename'
            : null;


        // Check if the widget is still mounted before navigating
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResultScreen(
              // --- ADDED: Pass the original video URL ---
              originalVideoUrl: originalVideoUrl,
              // ---
              clipUrls: clipUrls,
              summaryUrl: summaryUrl,
              groundTruthUrls: gtUrls,
            ),
          ));
        }
      } else {
        // Error handling (already includes setting _isProcessing = false implicitly via the moved block)
        // Check if the widget is still mounted before showing snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: ${resp.statusCode}")),
          );
        }
      }
    } catch (e) {
      // Error handling (already includes setting _isProcessing = false implicitly via the moved block)
      // Check if the widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e")),
        );
      }
    }
    // --- REMOVED: Redundant _isProcessing = false; blocks at the end of try/catch ---
  }



  // Helper method for the action card - from Code 1
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap, // Disable tap when processing
      child: Container(
        height: 250,
        width: 150,
        decoration: BoxDecoration(
          color: _isProcessing ? Colors.grey.shade300 : Colors.white, // Optional: Change color when disabled
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isProcessing ? 0.05 : 0.1), // Optional: Adjust shadow when disabled
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: _isProcessing ? Colors.grey : Colors.deepPurple), // Optional: Adjust icon color
            const SizedBox(height: 10),
            Padding( // Added padding for text in case it's long
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle( // Use TextStyle, not const TextStyle
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isProcessing ? Colors.grey.shade700 : Colors.black87, // Optional: Adjust text color
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Apply AppBar theme
      appBar: AppBar(
        title: const Text('Home Page'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      // Apply Drawer theme and content
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.indigo.shade100, // Drawer background color
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // DrawerHeader with gradient and user info
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple, Colors.white], // Gradient theme
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage('assets/logo.png'),
                      backgroundColor: Colors.transparent,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userEmail ?? 'No email found',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.black),
                title: const Text('Home', style: TextStyle(color: Colors.black)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.black),
                title: const Text('Profile', style: TextStyle(color: Colors.black)),
                onTap: () {
                  if (!_isProcessing) { // Prevent navigation while processing
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.black)),
                onTap: () {
                  if (!_isProcessing) { // Prevent dialog while processing
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const Signin()),
                                        (Route<dynamic> route) => false,
                                  );
                                }
                              },
                              child: const Text('Logout'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
      // Apply Body theme from Code 1 and add loading overlay
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.deepPurple], // Body background gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack( // Use Stack to layer the main content and the loading overlay
          children: [
            // Main content (the action card)
            Center(
              child: _buildActionCard(
                icon: Icons.video_library,
                label: 'Pick Video from Gallery',
                onTap: _pickVideoFromGallery, // This onTap is handled in the helper
              ),
            ),

            // Loading Overlay
            if (_isProcessing) // Conditionally show the overlay
              Container(
                color: Colors.black54, // Semi-transparent black to dim the background
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.deepPurple, // Theme color for the spinner
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}