import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide BarcodeOverlay;
import 'package:image_picker/image_picker.dart';
import 'package:qr_scanner_app/features/barcode/widgets/barcode_overlay.dart';
import 'package:qr_scanner_app/features/barcode/widgets/barcode_scan_line.dart';

import '../result/result_screen.dart';
import '../generator/generator_screen.dart';
import '../history/history_screen.dart';
import '../favourites/favourites_screen.dart';
import '../../shared/widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/scan_record.dart';
import '../../core/providers/ad_provider/ads_provider.dart';
import '../../core/services/scan_history_service.dart';
import '../../core/utils/app_constants.dart';
import 'scanner_type.dart';
import 'widgets/qr_overlay.dart';
import 'widgets/scan_line.dart';
import 'widgets/scanner_top_bar.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ScannerType _scannerType = ScannerType.qr;

  // One controller, lives for the lifetime of this screen
  late MobileScannerController _cameraController;
  int _cameraSessionKey = 0;
  bool _isRouteVisible = true;

  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;

  bool _isFlashOn = false;
  bool _hasScanned = false;
  bool _isProcessingImage = false;

  static const _qrFrameConfig = ScanFrameConfig();
  static const _barcodeFrameConfig = BarcodeFrameConfig();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraController = _buildController(ScannerType.qr);

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isRouteVisible) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCamera();
    }
  }

  Future<void> _pauseCamera() async {
    if (_isFlashOn) {
      await _cameraController.toggleTorch();
    }
    await _cameraController.stop();
    if (mounted) {
      setState(() => _isFlashOn = false);
    }
  }

  Future<void> _resumeCamera() async {
    if (!mounted) return;

    await _cameraController.stop();
    await _cameraController.dispose();
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _isFlashOn = false;
      _cameraSessionKey++;
      _cameraController = _buildController(_scannerType);
    });
  }

  // ── Build a controller with the right formats for each type ──────────────

  MobileScannerController _buildController(ScannerType type) {
    if (type == ScannerType.barcode) {
      return MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        formats: [
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.itf14,
          BarcodeFormat.codabar,
        ],
      );
    }
    // QR — all formats (default)
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: [BarcodeFormat.qrCode],
    );
  }

  // ── Switch scanner type: dispose old controller, start fresh ─────────────

  Future<void> _switchTo(ScannerType type) async {
    if (type == _scannerType) return;

    // Stop and dispose the current controller first, then wait a beat
    // so the camera hardware fully releases before re-opening
    await _cameraController.stop();
    await _cameraController.dispose();

    // Small delay to let the camera hardware fully close
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    setState(() {
      _scannerType = type;
      _hasScanned = false;
      _isFlashOn = false;
      _cameraController = _buildController(type);
    });
  }

  void _navigateToGenerator() {
    _isRouteVisible = false;
    _pauseCamera();
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => GeneratorScreen(activeScannerType: _scannerType),
      ),
    ).then((result) {
      _isRouteVisible = true;
      _handleNavigationResult(result);
    });
  }

  void _navigateToHistory() {
    _isRouteVisible = false;
    _pauseCamera();
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => const HistoryScreen(),
      ),
    ).then((result) {
      _isRouteVisible = true;
      _handleNavigationResult(result);
    });
  }

  void _navigateToFavourites() {
    _isRouteVisible = false;
    _pauseCamera();
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => const FavouritesScreen(),
      ),
    ).then((result) {
      _isRouteVisible = true;
      _handleNavigationResult(result);
    });
  }

  void _handleNavigationResult(dynamic result) {
    if (!mounted) return;
    if (result is ScannerType) {
      _switchTo(result);
    } else if (result == 'generator') {
      _navigateToGenerator();
    } else if (result == 'history') {
      _navigateToHistory();
    } else if (result == 'favourites') {
      _navigateToFavourites();
    } else {
      _resumeCamera();
    }
  }

  // ── Detection ─────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;
    if (!mounted) return;

    _handleResult(barcode.rawValue!, barcode.format.name, source: 'scan');
  }

  void _handleResult(String value, String format, {required String source}) {
    if (_hasScanned) return;
    if (!mounted) return;

    setState(() {
      _hasScanned = true;
      _isFlashOn = false;
    });
    HapticFeedback.mediumImpact();
    _pauseCamera();

    // Auto-save scan record
    final recordId = DateTime.now().millisecondsSinceEpoch.toString();
    final record = ScanRecord(
      id: recordId,
      value: value,
      format: format,
      source: source,
      scannedAt: DateTime.now(),
      isFavourite: false,
    );
    ScanHistoryService.instance.addRecord(record);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            recordId: recordId,
            result: value,
            format: format,
          ),
        ),
      ).then((_) {
        if (!mounted) return;
        setState(() => _hasScanned = false);
        _resumeCamera();
      });
    });
  }

  Future<void> _showAdPromptDialog(AdProvider adProvider) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Color(0xFFFBBF24)),
              SizedBox(width: 8),
              Text('Daily Limit Reached', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'You have used your ${AppConstants.dailyGalleryScans} free gallery scans for today. Watch a quick video to unlock ${AppConstants.rewardedGalleryScans} more scans!',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (adProvider.loadedRewardedAd) {
                  adProvider.showRewardedAd(
                    onUserEarnedReward: () {
                      adProvider.addRewardedScans();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Unlocked ${AppConstants.rewardedGalleryScans} more gallery scans!',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  );
                } else {
                  // Fallback: If ad fails or isn't loaded yet, grant 1 free scan so the user isn't stuck, and try loading the ad again.
                  adProvider.addSingleScan(); // Grant exactly 1 scan fallback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Ad not ready yet. Granted 1 free scan anyway!', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  adProvider.loadAdsOnFirstUse(); // Force reload attempt
                }
              },
              child: const Text('Watch Ad', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessingImage) return;

    final adProvider = context.read<AdProvider>();
    // ADS DISABLED — gallery scan limit removed. All gallery scans are free.
    // When ads are re-enabled, restore:
    // if (adProvider.freeScansLeft <= 0) {
    //   _showAdPromptDialog(adProvider);
    //   return;
    // }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Decrement scan count — disabled (no scan limit active).
      // await adProvider.useFreeScan();

      if (!mounted) return;
      setState(() => _isProcessingImage = true);

      final result = await _cameraController.analyzeImage(image.path);

      if (!mounted) return;
      setState(() => _isProcessingImage = false);

      if (result == null ||
          result.barcodes.isEmpty ||
          result.barcodes.first.rawValue == null) {
        _showNoCodeFoundSnackbar();
        return;
      }

      final barcode = result.barcodes.first;
      final formatName = barcode.format.name;
      final isQr = formatName.toLowerCase() == 'qrcode';

      // Ensure that barcode mode only scans barcode and QR mode only scans QR
      if (_scannerType == ScannerType.barcode && isQr) {
        _showNoCodeFoundSnackbar();
        return;
      }
      if (_scannerType == ScannerType.qr && !isQr) {
        _showNoCodeFoundSnackbar();
        return;
      }

      _handleResult(barcode.rawValue!, formatName, source: 'gallery');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingImage = false);
      _showNoCodeFoundSnackbar();
    }
  }

  void _showNoCodeFoundSnackbar() {
    final isBarcode = _scannerType == ScannerType.barcode;
    final message = isBarcode
        ? 'No barcode found in this image'
        : 'No QR code found in this image';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: const Color(0xFF242424),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double _zoomFactor = 0.0;

  // ── Flash & Zoom ──────────────────────────────────────────────────────────

  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
    _cameraController.toggleTorch();
  }

  void _setZoom(double value) {
    setState(() {
      _zoomFactor = value;
    });
    _cameraController.setZoomScale(value);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isBarcode = _scannerType == ScannerType.barcode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: AppDrawer(
        activeScreen: isBarcode ? 'barcode_scanner' : 'qr_scanner',
        activeScannerType: _scannerType,
        onScannerTypeSelected: _switchTo,
        onGeneratorSelected: _navigateToGenerator,
        onHistoryTap: _navigateToHistory,
        onFavouritesTap: _navigateToFavourites,
      ),
      body: Stack(
        children: [
          // 1. Single camera feed — key forces rebuild when type changes
          KeyedSubtree(
            key: ValueKey('${_scannerType}_$_cameraSessionKey'),
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),

          // 2. Overlay — swaps between QR frame and barcode frame
          if (isBarcode)
            const BarcodeOverlay(config: _barcodeFrameConfig)
          else
            const QrOverlay(config: _qrFrameConfig),

          // 3. Scan line — swaps to match frame
          if (isBarcode)
            BarcodeScanLine(
              animation: _scanLineAnimation,
              config: _barcodeFrameConfig,
            )
          else
            ScanLine(
              animation: _scanLineAnimation,
              config: _qrFrameConfig,
            ),

          // 4. Top bar + hint
          SafeArea(
            child: Column(
              children: [
                ScannerTopBar(
                  onMenuTap: () =>
                      _scaffoldKey.currentState?.openDrawer(),
                  onFlashTap: _toggleFlash,
                  isFlashOn: _isFlashOn,
                  scannerType: _scannerType,
                  onGalleryTap: _pickFromGallery,
                  isProcessingGallery: _isProcessingImage,
                ),
                const Spacer(),
                
                // Zoom Slider
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withOpacity(0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _zoomFactor,
                            min: 0.0,
                            max: 1.0,
                            onChanged: _setZoom,
                          ),
                        ),
                      ),
                      const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _HintText(scannerType: _scannerType),
              ],
            ),
          ),

          // 5. Processing overlay
          if (_isProcessingImage) _ProcessingOverlay(),
        ],
      ),
    );
  }
}

// ── Processing overlay ────────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Scanning image...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  final ScannerType scannerType;

  const _HintText({required this.scannerType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 120),
      child: Text(
        scannerType == ScannerType.barcode
            ? 'Align the barcode within the frame'
            : 'Align the QR code within the frame',
        style: TextStyle(
          color: Colors.white.withOpacity(0.65),
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}