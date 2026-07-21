import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  AnimationController? _carController;
  Animation<double>? _carAnimation;
  Animation<double>? _slideAnimation;
  AnimationController? _slideController;
  bool _isNavigating = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Preload audio and start animations together
    _initSplash();
  }

  Future<void> _initSplash() async {
    try {
      // Initialize controllers first (before async operations)
      _carController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );

      // Car animation
      _carAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _carController!,
          curve: Curves.easeInOut,
        ),
      );

      _slideController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );


      _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _slideController!, curve: Curves.easeInOut),
      );

      // Now load & play audio
      await _audioPlayer.play(AssetSource('sounds/splash_sound2.mp3'));

      // Ensure UI is updated
      setState(() {});

      // Start animations
      _carController!.forward();

      _carController!.addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) _slideController!.forward();
        }
      });

      _slideController!.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && !_isNavigating) {
          _isNavigating = true;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => widget.nextScreen,
              transitionDuration: Duration.zero,
            ),
          );
        }
      });
    } catch (e) {
      print("Splash error: $e");
      if (mounted && !_isNavigating) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.nextScreen),
        );
      }
    }
  }

  @override
  void dispose() {
    _carController!.dispose();
    _slideController!.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Show a blank screen until controllers are initialized
    if (_carController == null || _slideController == null) {
      return Scaffold(body: Container(color: Colors.white));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Next screen (hidden until slide completes)
          widget.nextScreen,

          // Animated splash screen
          AnimatedBuilder(
            animation: Listenable.merge([_carController, _slideController]),
            builder: (context, _) {
              final slideValue = _carController!.isCompleted ? _slideAnimation!.value : 0.0;
              return Transform.translate(
                offset: Offset(0, -size.height * slideValue),
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      // Background road
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/road.png',
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Left passport placeholder
                      Positioned(
                        left: 20,
                        top: size.height / 2 - 70,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person, size: 80, color: Colors.grey),
                        ),
                      ),

                      // Right passport placeholder
                      Positioned(
                        right: 20,
                        top: size.height / 2 - 70,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person, size: 80, color: Colors.grey),
                        ),
                      ),

                      // Animated car
                      //if (_carController!.isAnimating)
                        Positioned(
                          // Starts below screen, moves upward
                          top: size.height - 150 - ((size.height + 300) * _customEaseAnimation(_carAnimation!.value)),
                          left: size.width / 2 - 75,
                          child: Image.asset('assets/images/car.png', width: 150),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  double _customEaseAnimation(double value) {
    // First half of animation (0.0-0.5) moves slower (downward)
    // Second half (0.5-1.0) moves faster (upward)
    if (value < 0.5) {
      // Slower start (downward journey)
      return value * 0.6; // 60% of normal speed
    } else {
      // Faster end (upward journey)
      // Map 0.5-1.0 to 0.3-1.0 (accelerating upward)
      return 0.3 + ((value - 0.5) * 1.4);
    }
  }
}