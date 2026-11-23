import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/providers/ad_provider/ads_provider.dart';
import '../../core/services/scan_history_service.dart';
import '../../shared/widgets/round_icon_button.dart';
import 'widgets/result_action_buttons.dart';
import 'widgets/result_content_card.dart';
import 'widgets/result_type_badge.dart';

/// Describes what kind of content a scanned code contains.
class _ContentType {
  final String label;
  final IconData icon;
  final Color color;
  final IconData actionIcon;
  final String actionLabel;
  final String Function(String raw) buildUrl;

  const _ContentType({
    required this.label,
    required this.icon,
    required this.color,
    required this.actionIcon,
    required this.actionLabel,
    required this.buildUrl,
  });
}

class ResultScreen extends StatefulWidget {
  final String recordId;
  final String result;
  final String format;

  const ResultScreen({
    super.key,
    required this.recordId,
    required this.result,
    required this.format,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isFavourite = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavouriteState();
  }

  Future<void> _loadFavouriteState() async {
    final history = await ScanHistoryService.instance.getHistory();
    final index = history.indexWhere((r) => r.id == widget.recordId);
    if (index != -1 && mounted) {
      setState(() {
        _isFavourite = history[index].isFavourite;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavourite() async {
    await ScanHistoryService.instance.toggleFavourite(widget.recordId);
    if (!mounted) return;
    setState(() {
      _isFavourite = !_isFavourite;
    });
  }

  // ── Determine if this was a QR or barcode scan ───────────────────────────

  bool get _isQrCode => widget.format.toLowerCase() == 'qrcode';

  String get _scannedTitle =>
      _isQrCode ? 'QR Code Scanned!' : 'Barcode Scanned!';

  // ── Content type detection ────────────────────────────────────────────────

  bool get _isUrl {
    final lower = widget.result.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  bool get _isEmail {
    final lower = widget.result.toLowerCase();
    return lower.startsWith('mailto:') ||
        RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(lower);
  }

  // ── Returns a typed descriptor — phone removed ───────────────────────────

  _ContentType? get _contentType {
    if (_isUrl) {
      return _ContentType(
        label: 'Website URL',
        icon: Icons.link_rounded,
        color: AppColors.urlColor,
        actionIcon: Icons.open_in_browser_rounded,
        actionLabel: 'Open',
        buildUrl: (r) => r.toLowerCase().startsWith('http') ? r : 'https://$r',
      );
    }
    if (_isEmail) {
      return _ContentType(
        label: 'Email Address',
        icon: Icons.email_outlined,
        color: AppColors.emailColor,
        actionIcon: Icons.send_rounded,
        actionLabel: 'Email',
        buildUrl: (r) => r.toLowerCase().startsWith('mailto:') ? r : 'mailto:$r',
      );
    }
    return null; // plain text / barcode number / anything else
  }

  // ── Launch action (URL or email only) ────────────────────────────────────

  Future<void> _launch() async {
    final type = _contentType;
    if (type == null) return;
    final uri = Uri.parse(type.buildUrl(widget.result));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Copy to clipboard ─────────────────────────────────────────────────────

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.result));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Copied to clipboard',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: AppColors.bgSurface,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final type = _contentType;
    final contentColor = type?.color ?? AppColors.textColor;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Back & Favourite buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    bgColor: AppColors.bgSurface,
                    onTap: () {
                      // ADS DISABLED — navigate directly.
                      // When ads are re-enabled, replace with:
                      // context.read<AdProvider>().tryShowAd(onDismissed: () => Navigator.pop(context));
                      Navigator.pop(context);
                    },
                  ),
                  if (!_isLoading)
                    RoundIconButton(
                      icon: _isFavourite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      iconColor: _isFavourite
                          ? const Color(0xFFFBBF24)
                          : Colors.white,
                      bgColor: AppColors.bgSurface,
                      onTap: _toggleFavourite,
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // Success icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: contentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: contentColor, size: 44),
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic title — QR Code Scanned! or Barcode Scanned!
              Center(
                child: Text(_scannedTitle, style: AppTextStyles.sectionTitle),
              ),

              const SizedBox(height: 6),

              Center(
                child: Text(
                  'Format: ${widget.format}',
                  style: AppTextStyles.caption,
                ),
              ),

              const SizedBox(height: 32),

              // Type badge (URL or Email only)
              if (type != null)
                ResultTypeBadge(
                  icon: type.icon,
                  label: type.label,
                  color: type.color,
                ),

              const SizedBox(height: 16),

              // Content card
              ResultContentCard(content: widget.result),

              const SizedBox(height: 24),

              // Copy is always shown. Open/Email only shown for URL/email.
              ResultActionButtons(
                onCopy: () => _copy(context),
                onPrimaryAction: type != null ? _launch : null,
                primaryIcon: type?.actionIcon,
                primaryLabel: type?.actionLabel,
                primaryColor: type?.color,
              ),

              const Spacer(),

              _ScanAgainButton(
                onTap: () {
                  // ADS DISABLED — navigate directly.
                  // When ads are re-enabled, replace with:
                  // context.read<AdProvider>().tryShowAd(onDismissed: () => Navigator.pop(context));
                  Navigator.pop(context);
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scan Again button ─────────────────────────────────────────────────────────

class _ScanAgainButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanAgainButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Scan Again', style: AppTextStyles.buttonLabel),
          ],
        ),
      ),
    );
  }
}