import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/models/scan_record.dart';
import '../../core/services/scan_history_service.dart';
import '../../core/providers/ad_provider/ads_provider.dart';
import '../../core/utils/app_constants.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/round_icon_button.dart';
import '../../shared/widgets/ad_banner.dart';
import '../scanner/scanner_type.dart';
import 'package:provider/provider.dart';

enum GeneratorTab { qr, barcode }

enum QrInputType { text, email, phone, wifi, vcard }

enum BarcodeTypeOption { code128, ean13, ean8, upcA, code39 }

class _QrTypeOption {
  final QrInputType type;
  final String label;
  final IconData icon;

  const _QrTypeOption(this.type, this.label, this.icon);
}

class _BarcodeFormatOption {
  final BarcodeTypeOption type;
  final String label;
  final Barcode barcode;

  const _BarcodeFormatOption(this.type, this.label, this.barcode);
}

class GeneratorScreen extends StatefulWidget {
  final ScannerType activeScannerType;

  const GeneratorScreen({
    super.key,
    required this.activeScannerType,
  });

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _qrCaptureKey = GlobalKey();
  final GlobalKey _barcodeCaptureKey = GlobalKey();

  GeneratorTab _activeTab = GeneratorTab.qr;

  // ── QR Code State ─────────────────────────────────────────────────────────
  QrInputType _selectedQrType = QrInputType.text;
  String? _qrErrorText;
  String? _generatedQrData;

  // QR Controllers
  final _qrTextController = TextEditingController();
  final _qrEmailToController = TextEditingController();
  final _qrEmailSubjectController = TextEditingController();
  final _qrEmailBodyController = TextEditingController();
  final _qrPhoneController = TextEditingController();
  final _qrWifiSsidController = TextEditingController();
  final _qrWifiPasswordController = TextEditingController();
  String _wifiSecurity = 'WPA';

  final _qrVcardNameController = TextEditingController();
  final _qrVcardPhoneController = TextEditingController();
  final _qrVcardEmailController = TextEditingController();
  final _qrVcardOrgController = TextEditingController();

  final List<_QrTypeOption> _qrInputTypes = const [
    _QrTypeOption(QrInputType.text, 'Text / URL', Icons.link_rounded),
    _QrTypeOption(QrInputType.email, 'Email', Icons.email_rounded),
    _QrTypeOption(QrInputType.phone, 'Phone', Icons.phone_rounded),
    _QrTypeOption(QrInputType.wifi, 'WiFi', Icons.wifi_rounded),
    _QrTypeOption(QrInputType.vcard, 'vCard', Icons.contact_page_rounded),
  ];

  // ── Barcode State ─────────────────────────────────────────────────────────
  BarcodeTypeOption _selectedBarcodeType = BarcodeTypeOption.code128;
  String? _barcodeErrorText;
  String? _generatedBarcodeData;
  BarcodeTypeOption? _generatedBarcodeType;

  final _barcodeTextController = TextEditingController();

  final List<_BarcodeFormatOption> _barcodeFormats = [
    _BarcodeFormatOption(BarcodeTypeOption.code128, 'Code 128', Barcode.code128()),
    _BarcodeFormatOption(BarcodeTypeOption.ean13, 'EAN-13', Barcode.ean13()),
    _BarcodeFormatOption(BarcodeTypeOption.ean8, 'EAN-8', Barcode.ean8()),
    _BarcodeFormatOption(BarcodeTypeOption.upcA, 'UPC-A', Barcode.upcA()),
    _BarcodeFormatOption(BarcodeTypeOption.code39, 'Code 39', Barcode.code39()),
  ];

  @override
  void dispose() {
    _qrTextController.dispose();
    _qrEmailToController.dispose();
    _qrEmailSubjectController.dispose();
    _qrEmailBodyController.dispose();
    _qrPhoneController.dispose();
    _qrWifiSsidController.dispose();
    _qrWifiPasswordController.dispose();
    _qrVcardNameController.dispose();
    _qrVcardPhoneController.dispose();
    _qrVcardEmailController.dispose();
    _qrVcardOrgController.dispose();
    _barcodeTextController.dispose();
    super.dispose();
  }

  // ── Capture PNG Image from Widget ──────────────────────────────────────────
  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing widget: $e');
      return null;
    }
  }

  // ── Save Image to Device Gallery ───────────────────────────────────────────
  Future<void> _saveToGallery(Uint8List bytes) async {
    try {
      final granted = await Gal.requestAccess();
      if (!granted) {
        _showSnackbar('Gallery permission denied');
        return;
      }
      await Gal.putImageBytes(bytes);
      _showSnackbar('Saved to Gallery successfully!');
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      _showSnackbar('Failed to save to gallery');
    }
  }

  // ── Share Image using Share Sheet ──────────────────────────────────────────
  Future<void> _shareCode(Uint8List bytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName.png').create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Generated $fileName',
      );
    } catch (e) {
      debugPrint('Error sharing: $e');
      _showSnackbar('Failed to share image');
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
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

  Future<void> _showGenerationLimitDialog(AdProvider adProvider) async {
    final adsRemaining = adProvider.generationRewardedAdsRemaining;
    final adsWatched = adProvider.generationRewardedAdsWatched;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: Color(0xFFFBBF24)),
              SizedBox(width: 8),
              Text(
                'Daily Limit Reached',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            adsWatched == 0
                ? 'You have used your ${AppConstants.dailyGenerationLimit} free generations for today. Watch ${AppConstants.rewardedAdsRequiredForGenerationBonus} quick videos to unlock ${AppConstants.rewardedGenerationBonus} more!'
                : 'Watch $adsRemaining more video${adsRemaining == 1 ? '' : 's'} to unlock ${AppConstants.rewardedGenerationBonus} more generations!',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (adProvider.loadedRewardedAd) {
                  adProvider.showRewardedAd(
                    onUserEarnedReward: () async {
                      await adProvider.recordGenerationRewardedAd();
                      if (!mounted) return;
                      if (adProvider.generationsLeft > 0) {
                        _showSnackbar(
                          'Unlocked ${AppConstants.rewardedGenerationBonus} more generations!',
                        );
                      } else if (adProvider.generationRewardedAdsRemaining > 0) {
                        _showSnackbar(
                          'Watch ${adProvider.generationRewardedAdsRemaining} more video to unlock ${AppConstants.rewardedGenerationBonus} generations!',
                        );
                        _showGenerationLimitDialog(adProvider);
                      }
                    },
                  );
                } else {
                  adProvider.loadAdsOnFirstUse();
                  _showSnackbar('Ad not ready yet. Please try again in a moment.');
                }
              },
              child: Text(
                adsWatched == 0 ? 'Watch Ad (1/${AppConstants.rewardedAdsRequiredForGenerationBonus})' : 'Watch Ad (${adsWatched + 1}/${AppConstants.rewardedAdsRequiredForGenerationBonus})',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkGenerationLimit() async {
    // ADS DISABLED — generation limit removed. All generations are free.
    // When ads are re-enabled, restore:
    // final adProvider = context.read<AdProvider>();
    // if (adProvider.generationsLeft <= 0) {
    //   await _showGenerationLimitDialog(adProvider);
    //   return false;
    // }
    return true;
  }

  // ── QR Code Generation ─────────────────────────────────────────────────────
  Future<void> _generateQrCode() async {
    String? error;
    String data = '';

    switch (_selectedQrType) {
      case QrInputType.text:
        final text = _qrTextController.text.trim();
        if (text.isEmpty) {
          error = 'Please enter text or a URL';
        } else {
          data = text;
        }
        break;
      case QrInputType.email:
        final to = _qrEmailToController.text.trim();
        final subject = _qrEmailSubjectController.text.trim();
        final body = _qrEmailBodyController.text.trim();
        if (to.isEmpty) {
          error = 'Recipient email is required';
        } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(to)) {
          error = 'Please enter a valid email address';
        } else {
          data = 'mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
        }
        break;
      case QrInputType.phone:
        final phone = _qrPhoneController.text.trim();
        if (phone.isEmpty) {
          error = 'Phone number is required';
        } else {
          data = 'tel:$phone';
        }
        break;
      case QrInputType.wifi:
        final ssid = _qrWifiSsidController.text.trim();
        final password = _qrWifiPasswordController.text;
        if (ssid.isEmpty) {
          error = 'WiFi SSID (Network Name) is required';
        } else if (_wifiSecurity != 'None' && password.isEmpty) {
          error = 'WiFi Password is required';
        } else {
          data = 'WIFI:S:$ssid;T:${_wifiSecurity == 'None' ? 'nopass' : _wifiSecurity};P:${_wifiSecurity == 'None' ? '' : password};;';
        }
        break;
      case QrInputType.vcard:
        final name = _qrVcardNameController.text.trim();
        final phone = _qrVcardPhoneController.text.trim();
        final email = _qrVcardEmailController.text.trim();
        final org = _qrVcardOrgController.text.trim();
        if (name.isEmpty) {
          error = 'Name is required for vCard';
        } else {
          data = 'BEGIN:VCARD\n'
              'VERSION:3.0\n'
              'N:$name\n'
              'FN:$name\n'
              '${phone.isNotEmpty ? 'TEL:$phone\n' : ''}'
              '${email.isNotEmpty ? 'EMAIL:$email\n' : ''}'
              '${org.isNotEmpty ? 'ORG:$org\n' : ''}'
              'END:VCARD';
        }
        break;
    }

    FocusScope.of(context).unfocus();

    if (error != null) {
      setState(() {
        _qrErrorText = error;
        _generatedQrData = null;
      });
      return;
    }

    if (!await _checkGenerationLimit()) return;
    if (!mounted) return;

    // ADS DISABLED — generation counter disabled.
    // final adProvider = context.read<AdProvider>();
    // await adProvider.useGeneration();

    if (!mounted) return;

    setState(() {
      _qrErrorText = null;
      _generatedQrData = data;
      final record = ScanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        value: data,
        format: 'qrcode',
        source: 'generated',
        scannedAt: DateTime.now(),
      );
      ScanHistoryService.instance.addRecord(record);
    });
  }

  // ── Barcode Validation ─────────────────────────────────────────────────────
  String? _validateBarcodeValue(String value) {
    if (value.isEmpty) {
      return 'Please enter a value';
    }

    // Basic format checks first
    switch (_selectedBarcodeType) {
      case BarcodeTypeOption.code128:
        if (!RegExp(r'^[\x00-\x7F]+$').hasMatch(value)) {
          return 'Value must contain ASCII characters only';
        }
        break;
      case BarcodeTypeOption.ean13:
        if (!RegExp(r'^\d+$').hasMatch(value)) {
          return 'Value must contain digits only';
        }
        if (value.length != 12 && value.length != 13) {
          return 'EAN-13 must be exactly 12 or 13 digits';
        }
        break;
      case BarcodeTypeOption.ean8:
        if (!RegExp(r'^\d+$').hasMatch(value)) {
          return 'Value must contain digits only';
        }
        if (value.length != 7 && value.length != 8) {
          return 'EAN-8 must be exactly 7 or 8 digits';
        }
        break;
      case BarcodeTypeOption.upcA:
        if (!RegExp(r'^\d+$').hasMatch(value)) {
          return 'Value must contain digits only';
        }
        if (value.length != 11 && value.length != 12) {
          return 'UPC-A must be exactly 11 or 12 digits';
        }
        break;
      case BarcodeTypeOption.code39:
        if (!RegExp(r'^[A-Z0-9\-\.\$\/\+\%\s]+$').hasMatch(value)) {
          return r'Only A-Z, 0-9, space, and - . $ / + % are allowed';
        }
        break;
    }

    // Try-catch verification to prevent crashes from the barcode package
    final barcode = _getBarcodeWidgetType(_selectedBarcodeType);
    try {
      barcode.verify(value);
    } catch (e) {
      switch (_selectedBarcodeType) {
        case BarcodeTypeOption.ean13:
          return 'Invalid EAN-13 checksum';
        case BarcodeTypeOption.ean8:
          return 'Invalid EAN-8 checksum';
        case BarcodeTypeOption.upcA:
          return 'Invalid UPC-A checksum';
        default:
          return 'Invalid barcode value for this format';
      }
    }

    return null;
  }

  String _getFormatString(BarcodeTypeOption type) {
    switch (type) {
      case BarcodeTypeOption.code128:
        return 'code128';
      case BarcodeTypeOption.ean13:
        return 'ean13';
      case BarcodeTypeOption.ean8:
        return 'ean8';
      case BarcodeTypeOption.upcA:
        return 'upcA';
      case BarcodeTypeOption.code39:
        return 'code39';
    }
  }

  Future<void> _generateBarcode() async {
    final val = _barcodeTextController.text.trim();
    final error = _validateBarcodeValue(val);

    FocusScope.of(context).unfocus();

    if (error != null) {
      setState(() {
        _barcodeErrorText = error;
        _generatedBarcodeData = null;
      });
      return;
    }

    if (!await _checkGenerationLimit()) return;
    if (!mounted) return;

    // ADS DISABLED — generation counter disabled.
    // final adProvider = context.read<AdProvider>();
    // await adProvider.useGeneration();

    if (!mounted) return;

    setState(() {
      _barcodeErrorText = null;
      _generatedBarcodeData = val;
      _generatedBarcodeType = _selectedBarcodeType;
      final record = ScanRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        value: val,
        format: _getFormatString(_selectedBarcodeType),
        source: 'generated',
        scannedAt: DateTime.now(),
      );
      ScanHistoryService.instance.addRecord(record);
    });
  }

  Barcode _getBarcodeWidgetType(BarcodeTypeOption option) {
    switch (option) {
      case BarcodeTypeOption.code128:
        return Barcode.code128();
      case BarcodeTypeOption.ean13:
        return Barcode.ean13();
      case BarcodeTypeOption.ean8:
        return Barcode.ean8();
      case BarcodeTypeOption.upcA:
        return Barcode.upcA();
      case BarcodeTypeOption.code39:
        return Barcode.code39();
    }
  }

  // ── Build Method ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // final generationsLeft = context.watch<AdProvider>().generationsLeft;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgDark,
      drawer: AppDrawer(
        activeScreen: 'generator',
        activeScannerType: widget.activeScannerType,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            /* ADS DISABLED - limit removed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$generationsLeft generation${generationsLeft == 1 ? '' : 's'} left today',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            */
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildTabSwitcher(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _activeTab == GeneratorTab.qr
                    ? _buildQrGeneratorView()
                    : _buildBarcodeGeneratorView(),
              ),
            ),
            // ADS DISABLED
            // const AdBanner(),
          ],
        ),
      ),
    );
  }

  // ── UI Components ──────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RoundIconButton(
            icon: Icons.menu_rounded,
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.textPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Generator',
                style: AppTextStyles.screenTitle,
              ),
            ],
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = GeneratorTab.qr),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeTab == GeneratorTab.qr
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'QR Code',
                  style: TextStyle(
                    color: _activeTab == GeneratorTab.qr
                        ? Colors.white
                        : Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = GeneratorTab.barcode),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _activeTab == GeneratorTab.barcode
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Barcode',
                  style: TextStyle(
                    color: _activeTab == GeneratorTab.barcode
                        ? Colors.white
                        : Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: QR Generator View ───────────────────────────────────────────────
  Widget _buildQrGeneratorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Input Type', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        _buildQrTypeChips(),
        const SizedBox(height: 20),
        _buildQrFields(),
        if (_qrErrorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _qrErrorText!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        _buildGenerateButton(
          label: 'Generate QR Code',
          icon: Icons.qr_code_rounded,
          onTap: _generateQrCode,
        ),
        if (_generatedQrData != null) ...[
          const SizedBox(height: 30),
          Center(
            child: RepaintBoundary(
              key: _qrCaptureKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _generatedQrData!,
                  version: QrVersions.auto,
                  size: 188.0, // 220 total width with padding (188 + 32)
                  gapless: false,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(
            onDownload: () async {
              final bytes = await _captureWidget(_qrCaptureKey);
              if (bytes != null) await _saveToGallery(bytes);
            },
            onShare: () async {
              final bytes = await _captureWidget(_qrCaptureKey);
              if (bytes != null) await _shareCode(bytes, 'qr_code');
            },
          ),
        ],
      ],
    );
  }

  Widget _buildQrTypeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _qrInputTypes.map((type) {
          final isSelected = _selectedQrType == type.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedQrType = type.type;
                  _qrErrorText = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected ? AppColors.primary : Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white70,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQrFields() {
    switch (_selectedQrType) {
      case QrInputType.text:
        return _buildTextField(
          controller: _qrTextController,
          label: 'Text or URL',
          hint: 'Enter text or URL to encode',
          prefixIcon: Icons.edit_rounded,
        );
      case QrInputType.email:
        return Column(
          children: [
            _buildTextField(
              controller: _qrEmailToController,
              label: 'To (Email)',
              hint: 'recipient@example.com',
              prefixIcon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _qrEmailSubjectController,
              label: 'Subject',
              hint: 'Enter email subject',
              prefixIcon: Icons.subject_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _qrEmailBodyController,
              label: 'Body',
              hint: 'Enter email body text',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
            ),
          ],
        );
      case QrInputType.phone:
        return _buildTextField(
          controller: _qrPhoneController,
          label: 'Phone Number',
          hint: '+1 234 567 8900',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        );
      case QrInputType.wifi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _qrWifiSsidController,
              label: 'Network Name (SSID)',
              hint: 'Enter network SSID',
              prefixIcon: Icons.wifi_rounded,
            ),
            const SizedBox(height: 12),
            if (_wifiSecurity != 'None') ...[
              _buildTextField(
                controller: _qrWifiPasswordController,
                label: 'Password',
                hint: 'Enter network password',
                prefixIcon: Icons.lock_rounded,
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Security Type',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _buildWifiSecurityDropdown(),
          ],
        );
      case QrInputType.vcard:
        return Column(
          children: [
            _buildTextField(
              controller: _qrVcardNameController,
              label: 'Full Name',
              hint: 'John Doe',
              prefixIcon: Icons.person_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _qrVcardPhoneController,
              label: 'Phone Number',
              hint: '+1 234 567 8900',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _qrVcardEmailController,
              label: 'Email',
              hint: 'john.doe@example.com',
              prefixIcon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _qrVcardOrgController,
              label: 'Organization',
              hint: 'Acme Corp',
              prefixIcon: Icons.business_rounded,
            ),
          ],
        );
    }
  }

  Widget _buildWifiSecurityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _wifiSecurity,
          dropdownColor: AppColors.bgCard,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white60),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          onChanged: (val) {
            if (val != null) {
              setState(() => _wifiSecurity = val);
            }
          },
          items: const [
            DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
            DropdownMenuItem(value: 'WEP', child: Text('WEP')),
            DropdownMenuItem(value: 'None', child: Text('None (Open)')),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: Barcode Generator View ──────────────────────────────────────────
  Widget _buildBarcodeGeneratorView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Barcode Format', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        _buildBarcodeFormatChips(),
        const SizedBox(height: 20),
        _buildTextField(
          controller: _barcodeTextController,
          label: 'Enter value',
          hint: _selectedBarcodeType == BarcodeTypeOption.ean13
              ? 'Enter 12-13 digits'
              : _selectedBarcodeType == BarcodeTypeOption.ean8
                  ? 'Enter 7-8 digits'
                  : _selectedBarcodeType == BarcodeTypeOption.upcA
                      ? 'Enter 11-12 digits'
                      : 'Enter text to encode',
          prefixIcon: Icons.view_week_rounded,
          keyboardType: (_selectedBarcodeType == BarcodeTypeOption.ean13 ||
                  _selectedBarcodeType == BarcodeTypeOption.ean8 ||
                  _selectedBarcodeType == BarcodeTypeOption.upcA)
              ? TextInputType.number
              : TextInputType.text,
        ),
        if (_barcodeErrorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _barcodeErrorText!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        _buildGenerateButton(
          label: 'Generate Barcode',
          icon: Icons.view_week_rounded,
          onTap: _generateBarcode,
        ),
        if (_generatedBarcodeData != null && _generatedBarcodeType != null) ...[
          const SizedBox(height: 30),
          Center(
            child: RepaintBoundary(
              key: _barcodeCaptureKey,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: BarcodeWidget(
                  barcode: _getBarcodeWidgetType(_generatedBarcodeType!),
                  data: _generatedBarcodeData!,
                  width: 220,
                  height: 90,
                  color: Colors.black,
                  style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(
            onDownload: () async {
              final bytes = await _captureWidget(_barcodeCaptureKey);
              if (bytes != null) await _saveToGallery(bytes);
            },
            onShare: () async {
              final bytes = await _captureWidget(_barcodeCaptureKey);
              if (bytes != null) await _shareCode(bytes, 'barcode');
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBarcodeFormatChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _barcodeFormats.map((option) {
          final isSelected = _selectedBarcodeType == option.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedBarcodeType = option.type;
                  _barcodeErrorText = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1,
                  ),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.primary, size: 20) : null,
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildGenerateButton({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.buttonLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required VoidCallback onDownload,
    required VoidCallback onShare,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDownload,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Download',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onShare,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
