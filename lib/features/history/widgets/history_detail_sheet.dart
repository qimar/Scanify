import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/scan_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/services/scan_history_service.dart';
import '../../result/widgets/result_action_buttons.dart';
import '../../result/widgets/result_content_card.dart';
import '../../result/widgets/result_type_badge.dart';

class HistoryDetailSheet extends StatefulWidget {
  final ScanRecord record;
  final VoidCallback onDeleted;
  final VoidCallback onFavouriteToggled;

  const HistoryDetailSheet({
    super.key,
    required this.record,
    required this.onDeleted,
    required this.onFavouriteToggled,
  });

  @override
  State<HistoryDetailSheet> createState() => _HistoryDetailSheetState();
}

class _HistoryDetailSheetState extends State<HistoryDetailSheet> {
  late bool _isFavourite;

  @override
  void initState() {
    super.initState();
    _isFavourite = widget.record.isFavourite;
  }

  // ── Content type detection ────────────────────────────────────────────────

  bool get _isUrl {
    final lower = widget.record.value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  bool get _isEmail {
    final lower = widget.record.value.toLowerCase();
    return lower.startsWith('mailto:') ||
        RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(lower);
  }

  _HistoryContentType? get _contentType {
    if (_isUrl) {
      return _HistoryContentType(
        label: 'Website URL',
        icon: Icons.link_rounded,
        color: AppColors.urlColor,
        actionIcon: Icons.open_in_browser_rounded,
        actionLabel: 'Open',
        buildUrl: (r) => r.toLowerCase().startsWith('http') ? r : 'https://$r',
      );
    }
    if (_isEmail) {
      return _HistoryContentType(
        label: 'Email Address',
        icon: Icons.email_outlined,
        color: AppColors.emailColor,
        actionIcon: Icons.send_rounded,
        actionLabel: 'Email',
        buildUrl: (r) => r.toLowerCase().startsWith('mailto:') ? r : 'mailto:$r',
      );
    }
    return null;
  }

  Future<void> _launch() async {
    final type = _contentType;
    if (type == null) return;
    final uri = Uri.parse(type.buildUrl(widget.record.value));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.record.value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Copied to clipboard',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: AppColors.bgSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year}  ·  $hour:$minute $period';
  }

  String _formatSource(String source) {
    switch (source) {
      case 'scan':
        return 'Scanned from camera';
      case 'gallery':
        return 'Scanned from image';
      case 'generated':
        return 'Generated code';
      default:
        return 'Unknown source';
    }
  }

  Future<void> _toggleFavourite() async {
    await ScanHistoryService.instance.toggleFavourite(widget.record.id);
    if (!mounted) return;
    setState(() {
      _isFavourite = !_isFavourite;
    });
    widget.onFavouriteToggled();
  }

  Future<void> _delete() async {
    await ScanHistoryService.instance.deleteRecord(widget.record.id);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final type = _contentType;
    final displayFormat = widget.record.format.toLowerCase() == 'qrcode'
        ? 'QR Code'
        : widget.record.format.toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle and top bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayFormat,
                style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
              ),
              IconButton(
                icon: Icon(
                  _isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _isFavourite ? const Color(0xFFFBBF24) : Colors.white70,
                ),
                onPressed: _toggleFavourite,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content type badge
          if (type != null) ...[
            ResultTypeBadge(
              icon: type.icon,
              label: type.label,
              color: type.color,
            ),
            const SizedBox(height: 12),
          ],

          // Content card
          ResultContentCard(content: widget.record.value),
          const SizedBox(height: 16),

          // Format + Source Info Row
          _buildInfoRow(
            icon: Icons.info_outline_rounded,
            label: '$displayFormat  ·  ${_formatSource(widget.record.source)}',
          ),
          const SizedBox(height: 10),

          // Date and Time Info Row
          _buildInfoRow(
            icon: Icons.access_time_rounded,
            label: _formatDateTime(widget.record.scannedAt),
          ),
          const SizedBox(height: 24),

          // Action buttons: Copy & launcher if url/email
          ResultActionButtons(
            onCopy: () => _copy(context),
            onPrimaryAction: type != null ? _launch : null,
            primaryIcon: type?.actionIcon,
            primaryLabel: type?.actionLabel,
            primaryColor: type?.color,
          ),
          const SizedBox(height: 16),

          // Red delete button
          GestureDetector(
            onTap: _delete,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Center(
                child: Text(
                  'Delete from history',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _HistoryContentType {
  final String label;
  final IconData icon;
  final Color color;
  final IconData actionIcon;
  final String actionLabel;
  final String Function(String raw) buildUrl;

  const _HistoryContentType({
    required this.label,
    required this.icon,
    required this.color,
    required this.actionIcon,
    required this.actionLabel,
    required this.buildUrl,
  });
}
