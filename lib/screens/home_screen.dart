import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../services/photo_storage_service.dart';
import 'gallery_screen.dart';
import 'catalog_screen.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/detection_service.dart';
import '../models/detection_result.dart';
import '../widgets/scan_overlay.dart';
import '../widgets/results_sheet.dart';
import '../models/pose_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'settings_screen.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

// route observer (frozen preview fix)
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isDetecting = false; // blocks double-tap
  bool _showFlash = false;
  bool _isFrontCamera = false;
  bool _flashOn = false;
  String _zoomLabel = '1x';
  int _timerSeconds = 0;
  String _statusMessage = '';
  bool _noPersonDetected = false;
  bool _screenDetected = false; // screen/photo detected
  List<PoseModel> _shootPoses = [];
  int _wheelCenterIndex = 0;
  late PageController _wheelController;
  PoseModel? _previewPose;
  bool _isGhostPreview = false;

  // measured bar heights
  final GlobalKey _topBarKey = GlobalKey();
  final GlobalKey _bottomBarKey = GlobalKey();

  // FOV/zoom fix defaults
  double _topBarHeight = 90;
  double _bottomBarHeight = 220;

  // zoom-out factor
  static const double _previewZoomOutFactor = 0.78;

  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;
  late AnimationController _statusFadeController;
  late Animation<double> _statusFade;

  static const _purple = Color(0xFF9C6FFF);
  static const _orange = Color(0xFF9C6FFF);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _scanLineAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_scanLineController);

    _statusFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _statusFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statusFadeController, curve: Curves.easeIn),
    );
    _wheelController = PageController(viewportFraction: 0.32);
    _initCamera();
  }

  // subscribe route observer
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  // pause preview on nav
  @override
  void didPushNext() {
    try {
      _cameraController?.pausePreview();
    } catch (_) {
      // ignore
    }
  }

  // resume preview on back
  @override
  void didPopNext() {
    try {
      _cameraController?.resumePreview();
    } catch (_) {
      // ignore
    }
  }

  // measure bar heights
  void _measureBarHeights() {
    final topBox = _topBarKey.currentContext?.findRenderObject() as RenderBox?;
    final bottomBox =
        _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
    final newTop = topBox?.size.height ?? _topBarHeight;
    final newBottom = bottomBox?.size.height ?? _bottomBarHeight;
    if ((newTop - _topBarHeight).abs() > 0.5 ||
        (newBottom - _bottomBarHeight).abs() > 0.5) {
      if (mounted) {
        setState(() {
          _topBarHeight = newTop;
          _bottomBarHeight = newBottom;
        });
      }
    }
  }

  Future<void> _initCamera({bool useFront = false}) async {
    setState(() => _isInitialized = false);
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    final selected = useFront
        ? _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          )
        : _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );
    await _cameraController?.dispose();
    _cameraController = CameraController(
      selected,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _cameraController!.initialize();

    // sync flash state
    try {
      await _cameraController!.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (_) {
      // unsupported device
    }

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _flipCamera() async {
    HapticFeedback.lightImpact();
    _isFrontCamera = !_isFrontCamera;
    await _initCamera(useFront: _isFrontCamera);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    HapticFeedback.lightImpact();
    setState(() => _flashOn = !_flashOn);
    await _cameraController!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  void _cycleTimer() {
    HapticFeedback.lightImpact();
    const options = [0, 3, 5, 10];
    final idx = options.indexOf(_timerSeconds);
    setState(() => _timerSeconds = options[(idx + 1) % options.length]);
  }

  Future<void> _cycleZoom() async {
    if (_cameraController == null) return;
    HapticFeedback.lightImpact();
    const options = ['1x', '1.5x', '2x'];
    final map = {'1x': 1.0, '1.5x': 1.5, '2x': 2.0};
    final idx = options.indexOf(_zoomLabel);
    final next = options[(idx + 1) % options.length];
    await _cameraController!.setZoomLevel(map[next]!);
    setState(() => _zoomLabel = next);
  }

  Future<void> _startScan() async {
    if (_isScanning || _isDetecting) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isDetecting = true;
      _noPersonDetected = false;
      _screenDetected = false;
    });

    ScanResult scanResult;
    try {
      // liveness check
      scanResult = await DetectionService.analyzeLiveness(_cameraController!)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              debugPrint(
                '⏱️ DetectionService.analyzeLiveness() timed out after 8s — treating as noPerson',
              );
              return ScanResult.noPerson;
            },
          );
    } catch (e, stack) {
      debugPrint('❌ DetectionService.analyzeLiveness() failed: $e');
      debugPrint('$stack');
      scanResult = ScanResult.noPerson;
    }

    if (!mounted) return;
    setState(() => _isDetecting = false);
    if (scanResult == ScanResult.noPerson) {
      setState(() {
        _isScanning = false;
        _statusMessage = '';
        _noPersonDetected = true;
      });
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _noPersonDetected = false);
      });
      return;
    }

    // screen detected case
    if (scanResult == ScanResult.screenDetected) {
      setState(() {
        _isScanning = false;
        _statusMessage = '';
        _screenDetected = true;
      });
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _screenDetected = false);
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _noPersonDetected = false;
      _statusMessage = '';
    });

    if (_timerSeconds > 0) {
      for (int i = _timerSeconds; i > 0; i--) {
        if (!mounted) return;
        await _statusFadeController.reverse();
        setState(() => _statusMessage = 'Starting in ${i}s...');
        _statusFadeController.forward(from: 0);
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (!mounted) return;
    await _statusFadeController.reverse();
    setState(() => _statusMessage = 'Scanning Environment...');
    _statusFadeController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final messages = ['Detecting Subject...', 'Generating Pose Ideas...'];
    for (final msg in messages) {
      if (!mounted) return;
      await _statusFadeController.reverse();
      setState(() => _statusMessage = msg);
      _statusFadeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _statusMessage = '';
    });
    HapticFeedback.lightImpact();

    _openCatalog(tabIndex: 0, scanResult: scanResult);
  }

  void _showResults(DetectionResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ResultsSheet(result: result, onSavePose: _savePose),
    );
  }

  Future<void> _savePose(PoseModel pose) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favourites') ?? [];
    final encoded = jsonEncode(pose.toJson());
    if (!saved.contains(encoded)) {
      saved.add(encoded);
      await prefs.setStringList('favourites', saved);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                '${pose.name} saved!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6B3FD4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openCatalog({int tabIndex = 1, ScanResult? scanResult}) async {
    final selected = await Navigator.push<List<PoseModel>>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogScreen(
          initiallySelected: _shootPoses,
          initialTabIndex: tabIndex,
          scanResult: scanResult,
        ),
      ),
    );
    if (selected != null) {
      setState(() => _shootPoses = selected);
    }
  }

  void _openGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryScreen()),
    );
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    HapticFeedback.mediumImpact();

    setState(() => _showFlash = true);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _showFlash = false);
    });

    try {
      final XFile file = await _cameraController!.takePicture();
      final finalPath = await _cropToVisibleArea(file.path);
      await PhotoStorageService.savePhoto(finalPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  // crop to visible area
  Future<String> _cropToVisibleArea(String originalPath) async {
    try {
      final screenSize = MediaQuery.of(context).size;

      final topBarBox =
          _topBarKey.currentContext?.findRenderObject() as RenderBox?;
      final bottomBarBox =
          _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
      final topBarHeight = topBarBox?.size.height ?? 0.0;
      final bottomBarHeight = bottomBarBox?.size.height ?? 0.0;

      // visible strip height
      final visibleStripHeight =
          (screenSize.height - topBarHeight - bottomBarHeight).clamp(
            1.0,
            screenSize.height,
          );

      // matches preview box calc
      final previewSize = _cameraController!.value.previewSize!;
      final boxW = previewSize.height / _previewZoomOutFactor;
      final boxH = previewSize.width / _previewZoomOutFactor;

      final scaleW = screenSize.width / boxW;
      final scaleH = visibleStripHeight / boxH;
      // cover-scale, no double factor
      final scale = scaleW > scaleH ? scaleW : scaleH;

      final displayedW = boxW * scale;
      final displayedH = boxH * scale;
      final extraW = displayedW - screenSize.width; // side crop
      final extraH = displayedH - visibleStripHeight; // top/bottom crop

      final fracLeftRight = extraW > 0 ? (extraW / 2) / scale / boxW : 0.0;
      final fracTopBottomFromCover = extraH > 0
          ? (extraH / 2) / scale / boxH
          : 0.0;

      // no extra bar overlap
      final totalTopFrac = fracTopBottomFromCover;
      final totalBottomFrac = fracTopBottomFromCover;
      final totalLeftFrac = fracLeftRight;
      final totalRightFrac = fracLeftRight;

      final bytes = await File(originalPath).readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return originalPath;

      // bake EXIF orientation
      decoded = img.bakeOrientation(decoded);

      final imgW = decoded.width;
      final imgH = decoded.height;

      final cropLeft = (imgW * totalLeftFrac).round().clamp(0, imgW - 1);
      final cropRight = (imgW * totalRightFrac).round().clamp(0, imgW - 1);
      final cropTop = (imgH * totalTopFrac).round().clamp(0, imgH - 1);
      final cropBottom = (imgH * totalBottomFrac).round().clamp(0, imgH - 1);

      final newW = (imgW - cropLeft - cropRight).clamp(1, imgW);
      final newH = (imgH - cropTop - cropBottom).clamp(1, imgH);

      final cropped = img.copyCrop(
        decoded,
        x: cropLeft,
        y: cropTop,
        width: newW,
        height: newH,
      );

      // final ratio crop
      const targetRatio = 3 / 4; // portrait 4:3
      final curW = cropped.width;
      final curH = cropped.height;
      final curRatio = curW / curH;

      img.Image finalImage;
      if (curRatio > targetRatio) {
        // crop width
        final newFinalW = (curH * targetRatio).round().clamp(1, curW);
        final xOffset = ((curW - newFinalW) / 2).round().clamp(
          0,
          curW - newFinalW,
        );
        finalImage = img.copyCrop(
          cropped,
          x: xOffset,
          y: 0,
          width: newFinalW,
          height: curH,
        );
      } else {
        // crop height
        final newFinalH = (curW / targetRatio).round().clamp(1, curH);
        final yOffset = ((curH - newFinalH) / 2).round().clamp(
          0,
          curH - newFinalH,
        );
        finalImage = img.copyCrop(
          cropped,
          x: 0,
          y: yOffset,
          width: curW,
          height: newFinalH,
        );
      }

      final croppedBytes = img.encodeJpg(finalImage, quality: 92);
      await File(originalPath).writeAsBytes(croppedBytes);
      return originalPath;
    } catch (e, stack) {
      debugPrint('❌ _cropToVisibleArea failed: $e');
      debugPrint('$stack');
      // keep original on fail
      return originalPath;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _cameraController?.dispose();
    _wheelController.dispose();
    _scanLineController.dispose();
    _statusFadeController.dispose();
    DetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // measure bars post-frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBarHeights());

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        // system brightness check
        final brightness = themeMode == ThemeMode.system
            ? MediaQuery.of(context).platformBrightness
            : (themeMode == ThemeMode.dark
                  ? Brightness.dark
                  : Brightness.light);
        final isDark = brightness == Brightness.dark;

        // theme colors
        final barBg = isDark ? Colors.black : const Color(0xFFF2F0F7);
        final iconBg = isDark
            ? Colors.black.withOpacity(0.5)
            : const Color(0x12000000);
        final iconBorder = isDark
            ? Colors.white.withOpacity(0.2)
            : const Color(0x26000000);
        final iconColor = isDark ? Colors.white : const Color(0xFF2D2D2D);
        final hintColor = isDark ? Colors.white54 : const Color(0xFF9B96B0);
        final pillBg = isDark
            ? Colors.white.withOpacity(0.08)
            : const Color(0x0F000000);
        final pillTextColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
        final scanIconColor = isDark
            ? const Color(0xFFE8A020)
            : const Color(0xFFC47A00);
        final sideBtnBg = isDark
            ? Colors.black.withOpacity(0.5)
            : const Color(0x12000000);
        final sideBtnBorder = isDark
            ? Colors.white.withOpacity(0.5)
            : const Color(0x33000000);

        // status bar brightness
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: barBg,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
        );

        final topPad = MediaQuery.of(context).padding.top;
        final bottomPad = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // full screen camera
              if (_isInitialized && _cameraController != null)
                Positioned(
                  top: _topBarHeight,
                  bottom: _bottomBarHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    // blends gap w/ bg
                    color: Colors.black,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          // inflated size, safe zoom-out
                          width:
                              _cameraController!.value.previewSize!.height /
                              _previewZoomOutFactor,
                          height:
                              _cameraController!.value.previewSize!.width /
                              _previewZoomOutFactor,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: _purple,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),

              // scan grid overlay
              if (_isScanning)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (_, __) => CustomPaint(
                      painter: _GridScanPainter(
                        progress: _scanLineAnim.value,
                        color: _purple,
                      ),
                    ),
                  ),
                ),

              // corner brackets
              Positioned.fill(
                child: CustomPaint(painter: _CornerPainter(color: _orange)),
              ),

              // pose preview overlay
              Positioned.fill(
                child: IgnorePointer(
                  // don't block camera taps
                  ignoring: _previewPose == null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (!_isGhostPreview) {
                          // solid -> ghost mode
                          _isGhostPreview = true;
                        } else {
                          // close preview
                          _previewPose = null;
                          _isGhostPreview = false;
                        }
                      });
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      // scale+fade transition
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.5,
                            end:
                                1.0, // thoda chota target — overshoot ke baad bhi 'too big' nahi lagega
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _previewPose == null
                          ? const SizedBox.expand(
                              key: ValueKey('empty-preview'),
                            )
                          : Container(
                              key: ValueKey<String?>(_previewPose!.imagePath),
                              // transparent, tap area only
                              color: Colors.transparent,
                              padding: EdgeInsets.only(
                                top: topPad + 55,
                                bottom: bottomPad + 110,
                              ),
                              child: Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 250),
                                  scale: _isGhostPreview ? 0.98 : 0.75,
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 250),
                                    opacity: _isGhostPreview ? 0.45 : 1.0,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: _previewPose!.imagePath != null
                                          ? (_previewPose!.imagePath!
                                                    .startsWith('/')
                                                ? Image.file(
                                                    File(
                                                      _previewPose!.imagePath!,
                                                    ),
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => Container(
                                                          color: const Color(
                                                            0xFF1A1A1A,
                                                          ),
                                                          child: const Icon(
                                                            Icons.image,
                                                            color:
                                                                Colors.white38,
                                                            size: 40,
                                                          ),
                                                        ),
                                                  )
                                                : Image.asset(
                                                    _previewPose!.imagePath!,
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          __,
                                                          ___,
                                                        ) => Container(
                                                          color: const Color(
                                                            0xFF1A1A1A,
                                                          ),
                                                          child: const Icon(
                                                            Icons.image,
                                                            color:
                                                                Colors.white38,
                                                            size: 40,
                                                          ),
                                                        ),
                                                  ))
                                          : Container(
                                              color: const Color(0xFF1A1A1A),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // shutter flash
              Positioned.fill(
                child: IgnorePointer(
                  // visual only, no taps
                  child: AnimatedOpacity(
                    opacity: _showFlash ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(color: Colors.black),
                  ),
                ),
              ),

              // top bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  key: _topBarKey,
                  color: barBg,
                  padding: EdgeInsets.only(
                    top: topPad + 6,
                    left: 14,
                    right: 14,
                    bottom: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleTopBtn(
                        icon: Icons.settings_outlined,
                        iconColor: iconColor,
                        bgColor: iconBg,
                        borderColor: iconBorder,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _CircleTopBtn(
                            icon: Icons.timer_outlined,
                            label: _timerSeconds == 0
                                ? null
                                : '${_timerSeconds}s',
                            active: _timerSeconds > 0,
                            activeColor: _orange,
                            iconColor: iconColor,
                            bgColor: iconBg,
                            borderColor: iconBorder,
                            onTap: _cycleTimer,
                          ),
                          const SizedBox(width: 8),
                          _CircleTopBtn(
                            icon: _flashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            active: _flashOn,
                            activeColor: _orange,
                            iconColor: iconColor,
                            bgColor: iconBg,
                            borderColor: iconBorder,
                            onTap: _toggleFlash,
                          ),
                          const SizedBox(width: 8),
                          _ZoomBtn(
                            label: _zoomLabel,
                            textColor: iconColor,
                            bgColor: iconBg,
                            borderColor: iconBorder,
                            onTap: _cycleZoom,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // scanning status
              if (_isScanning && _statusMessage.isNotEmpty)
                Positioned(
                  bottom: bottomPad + 100,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _statusFade,
                    child: Center(
                      child: Text(
                        _statusMessage.toUpperCase(),
                        style: const TextStyle(
                          color: _orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),

              // no person detected
              if (_noPersonDetected && !_isScanning)
                Positioned(
                  top: topPad + 70,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFE24B4A),
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'No person detected. Rescan.',
                            style: TextStyle(
                              color: Color(0xFFF09595),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // screen detected
              if (_screenDetected && !_isScanning)
                Positioned(
                  top: topPad + 70,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smartphone_rounded,
                            color: Color(0xFFE24B4A),
                            size: 15,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Screen/photo detected. Scan a real person.',
                            style: TextStyle(
                              color: Color(0xFFF09595),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  key: _bottomBarKey,
                  color: barBg,
                  padding: EdgeInsets.only(
                    top: 14,
                    left: 20,
                    right: 20,
                    bottom: bottomPad + 10,
                  ),
                  // no hardcoded height
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: IgnorePointer(
                          child: _buildDetectBottom(
                            iconColor: iconColor,
                            hintColor: hintColor,
                            pillBg: pillBg,
                            pillTextColor: pillTextColor,
                            scanIconColor: scanIconColor,
                            sideBtnBg: sideBtnBg,
                            sideBtnBorder: sideBtnBorder,
                            isDark: isDark,
                            forceEmpty: true,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isScanning
                            ? _buildScanningBottom(
                                iconColor: iconColor,
                                sideBtnBg: sideBtnBg,
                                sideBtnBorder: sideBtnBorder,
                                isDark: isDark,
                              )
                            : _buildDetectBottom(
                                iconColor: iconColor,
                                hintColor: hintColor,
                                pillBg: pillBg,
                                pillTextColor: pillTextColor,
                                scanIconColor: scanIconColor,
                                sideBtnBg: sideBtnBg,
                                sideBtnBorder: sideBtnBorder,
                                isDark: isDark,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetectBottom({
    required Color iconColor,
    required Color hintColor,
    required Color pillBg,
    required Color pillTextColor,
    required Color scanIconColor,
    required Color sideBtnBg,
    required Color sideBtnBorder,
    required bool isDark,
    bool forceEmpty = false,
  }) {
    if (_shootPoses.isEmpty || forceEmpty) {
      return Column(
        key: const ValueKey('detect-empty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add poses to your camera',
            style: TextStyle(
              color: hintColor,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          _WidePill(
            icon: Icons.crop_free_rounded,
            label: 'Scan scene to add poses',
            iconColor: scanIconColor,
            bgColor: pillBg,
            textColor: pillTextColor,
            onTap: () {
              setState(() => _noPersonDetected = false);
              _startScan();
            },
          ),
          const SizedBox(height: 8),
          _WidePill(
            icon: Icons.person_outline_rounded,
            label: 'Select poses from catalog',
            iconColor: _purple,
            bgColor: pillBg,
            textColor: pillTextColor,
            onTap: _openCatalog,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SideBtn(
                icon: Icons.photo_library_rounded,
                iconColor: iconColor,
                bgColor: sideBtnBg,
                borderColor: sideBtnBorder,
                onTap: _openGallery,
              ),
              _SideBtn(
                icon: Icons.flip_camera_android_outlined,
                iconColor: iconColor,
                bgColor: sideBtnBg,
                borderColor: sideBtnBorder,
                onTap: _flipCamera,
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('detect-with-poses'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _PoseWheelCarousel(
          poses: _shootPoses,
          controller: _wheelController,
          previewedPose: _previewPose,
          isDark: isDark,
          onCenterChanged: (index) {
            setState(() {
              _wheelCenterIndex = index;
              // sync big preview too
              if (_previewPose != null) {
                _previewPose = _shootPoses[index];
              }
            });
          },
          onPoseTap: (pose) {
            setState(() {
              _previewPose = (_previewPose == pose) ? null : pose;
              _isGhostPreview = false;
            });
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SideBtn(
              icon: Icons.photo_library_rounded,
              iconColor: iconColor,
              bgColor: sideBtnBg,
              borderColor: sideBtnBorder,
              onTap: _openGallery,
            ),
            _SideBtn(
              icon: Icons.crop_free_rounded,
              iconColor: iconColor,
              bgColor: sideBtnBg,
              borderColor: sideBtnBorder,
              onTap: () {
                setState(() => _noPersonDetected = false);
                _startScan();
              },
            ),
            _ShutterBtn(
              isScanning: false,
              isDark: isDark,
              onTap: _capturePhoto,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _SideBtn(
                  icon: Icons.person_outline_rounded,
                  iconColor: iconColor,
                  bgColor: sideBtnBg,
                  borderColor: sideBtnBorder,
                  onTap: _openCatalog,
                ),
                if (_shootPoses.isNotEmpty)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          '${_shootPoses.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            _SideBtn(
              icon: Icons.flip_camera_android_outlined,
              iconColor: iconColor,
              bgColor: sideBtnBg,
              borderColor: sideBtnBorder,
              onTap: _flipCamera,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanningBottom({
    required Color iconColor,
    required Color sideBtnBg,
    required Color sideBtnBorder,
    required bool isDark,
  }) {
    return Row(
      key: const ValueKey('scanning'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SideBtn(
          icon: Icons.photo_library_rounded,
          iconColor: iconColor,
          bgColor: sideBtnBg,
          borderColor: sideBtnBorder,
          onTap: _openGallery,
        ),
        _ShutterBtn(isScanning: true, isDark: isDark, onTap: null),
        _SideBtn(
          icon: Icons.flip_camera_android_outlined,
          iconColor: iconColor,
          bgColor: sideBtnBg,
          borderColor: sideBtnBorder,
          onTap: _flipCamera,
        ),
      ],
    );
  }
}

// ── Reusable Widgets ──

class _CircleTopBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final Color activeColor;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _CircleTopBtn({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    this.label,
    this.active = false,
    this.activeColor = const Color(0xFF9C6FFF),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? activeColor.withOpacity(0.15) : bgColor,
          border: Border.all(
            color: active ? activeColor.withOpacity(0.6) : borderColor,
            width: 0.8,
          ),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: active ? activeColor : iconColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Icon(icon, color: active ? activeColor : iconColor, size: 17),
        ),
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ZoomBtn({
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _WidePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const _WidePill({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bgColor,
    required this.textColor,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 17),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _SideBtn({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

class _DottedSideBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _DottedSideBtn({
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
        child: CustomPaint(
          painter: _DottedCirclePainter(color: iconColor.withOpacity(0.5)),
          child: Center(child: Icon(icon, color: iconColor, size: 20)),
        ),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  _DottedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final radius = size.width / 2;
    const dashCount = 20;
    final sweep = (2 * 3.14159265 / dashCount) * 0.5;
    for (int i = 0; i < dashCount; i++) {
      final start = i * (2 * 3.14159265 / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius - 1),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShutterBtn extends StatelessWidget {
  final bool isScanning;
  final bool isDark;
  final VoidCallback? onTap;

  const _ShutterBtn({
    required this.isScanning,
    required this.onTap,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    // theme-aware inner circle
    final innerIdleColor = isDark ? Colors.black : const Color(0xFFF2F0F7);
    final innerBorder = isDark
        ? null
        : Border.all(color: const Color(0x26000000), width: 1);
    final scanningOverlayColor = isDark
        ? Colors.white
        : const Color(0xFF6B2FD6);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9C2FF), Color(0xFF6B2FD6)],
          ),
        ),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isScanning
                  ? const Color(0xFF9C6FFF).withOpacity(0.4)
                  : innerIdleColor,
              border: isScanning ? null : innerBorder,
            ),
            child: isScanning
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: scanningOverlayColor,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double m = 20;
    const double len = 30;
    final double b = size.height - 20;

    canvas.drawLine(Offset(m, m + len), Offset(m, m), paint);
    canvas.drawLine(Offset(m, m), Offset(m + len, m), paint);
    canvas.drawLine(
      Offset(size.width - m, m + len),
      Offset(size.width - m, m),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m - len, m),
      paint,
    );
    canvas.drawLine(Offset(m, b - len), Offset(m, b), paint);
    canvas.drawLine(Offset(m, b), Offset(m + len, b), paint);
    canvas.drawLine(
      Offset(size.width - m, b - len),
      Offset(size.width - m, b),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - m, b),
      Offset(size.width - m - len, b),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _GridScanPainter extends CustomPainter {
  final double progress;
  final Color color;
  _GridScanPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withOpacity(0.07)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final scanY = size.height * 0.08 + (size.height * 0.82 * progress);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color,
          Colors.white,
          color,
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 2))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(_GridScanPainter old) => old.progress != progress;
}

class _PoseWheelCarousel extends StatefulWidget {
  final List<PoseModel> poses;
  final PageController controller;
  final ValueChanged<int> onCenterChanged;
  final ValueChanged<PoseModel>? onPoseTap;
  final PoseModel? previewedPose;
  final bool isDark;

  const _PoseWheelCarousel({
    required this.poses,
    required this.controller,
    required this.onCenterChanged,
    this.onPoseTap,
    this.previewedPose,
    this.isDark = true,
  });

  @override
  State<_PoseWheelCarousel> createState() => _PoseWheelCarouselState();
}

class _PoseWheelCarouselState extends State<_PoseWheelCarousel> {
  double _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    setState(() => _page = widget.controller.page ?? 0);
    final nearest = _page.round().clamp(0, widget.poses.length - 1);
    widget.onCenterChanged(nearest);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // theme-aware tile bg
    final tileBg = widget.isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE7E4EF);
    final placeholderIconColor = widget.isDark
        ? Colors.white38
        : const Color(0xFF9B96B0);

    return SizedBox(
      height: 78,
      child: PageView.builder(
        controller: widget.controller,
        itemCount: widget.poses.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final diff = (index - _page);
          final absDiff = diff.abs().clamp(0.0, 2.0);
          final scale = 1.0 - (absDiff * 0.28).clamp(0.0, 0.55);
          final angle = diff * 0.55;
          final verticalOffset = absDiff * absDiff * 14;
          final opacity = (1.0 - absDiff * 0.35).clamp(0.55, 1.0);
          final isBeingPreviewed = widget.poses[index] == widget.previewedPose;

          if (isBeingPreviewed) {
            // leave gap, no dupe
            return const SizedBox(width: 64, height: 78);
          }

          return GestureDetector(
            onTap: () {
              final isAlreadyCentered = index == _page.round();
              if (isAlreadyCentered) {
                // already centered, show preview
                widget.onPoseTap?.call(widget.poses[index]);
              } else {
                // center first, then preview
                widget.controller.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            child: Transform.translate(
              offset: Offset(0, verticalOffset),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(angle * 0.4),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: widget.isDark ? Colors.transparent : tileBg,
                          boxShadow: absDiff < 0.3
                              ? (widget.isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    // soft ambient + contact shadow
                                    : [
                                        BoxShadow(
                                          color: const Color(0x14000000),
                                          blurRadius: 14,
                                          spreadRadius: -4,
                                          offset: const Offset(0, 6),
                                        ),
                                        BoxShadow(
                                          color: const Color(0x0F000000),
                                          blurRadius: 3,
                                          spreadRadius: -1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ])
                              : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: widget.poses[index].imagePath != null
                              ? (widget.poses[index].imagePath!.startsWith('/')
                                    ? Image.file(
                                        File(widget.poses[index].imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: tileBg,
                                          child: Icon(
                                            Icons.image,
                                            color: placeholderIconColor,
                                            size: 22,
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        widget.poses[index].imagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: tileBg,
                                          child: Icon(
                                            Icons.image,
                                            color: placeholderIconColor,
                                            size: 22,
                                          ),
                                        ),
                                      ))
                              : Container(color: tileBg),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
