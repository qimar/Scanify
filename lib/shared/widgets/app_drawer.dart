import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/scanner/scanner_type.dart';

const String _kAppPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.example.scanify';
const String _kShareText =
    'Check out this amazing QR & Barcode Scanner app! 📱\n'
    'Scan QR codes and barcodes instantly, generate your own, and keep\n'
    'track of your scan history — all for free.\n'
    'Download it here: $_kAppPlayStoreUrl';
const String _kDeveloperPageUrl =
    'https://play.google.com/store/apps/developer?id=Example+Developer';

class AppDrawer extends StatelessWidget {
  final String activeScreen; // 'qr_scanner', 'barcode_scanner', 'generator', 'history', 'favourites'
  final ScannerType activeScannerType;
  final ValueChanged<ScannerType>? onScannerTypeSelected;
  final VoidCallback? onGeneratorSelected;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onFavouritesTap;

  const AppDrawer({
    super.key,
    required this.activeScreen,
    required this.activeScannerType,
    this.onScannerTypeSelected,
    this.onGeneratorSelected,
    this.onHistoryTap,
    this.onFavouritesTap,
  });

  bool get _isPushedScreen =>
      activeScreen == 'generator' ||
      activeScreen == 'history' ||
      activeScreen == 'favourites';

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DrawerHeader(),
            const SizedBox(height: 8),
            _DrawerItemTile(
              icon: Icons.qr_code_scanner_rounded,
              label: 'QR Scanner',
              isActive: activeScreen == 'qr_scanner',
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (_isPushedScreen) {
                  Navigator.pop(context, ScannerType.qr);
                } else if (onScannerTypeSelected != null) {
                  onScannerTypeSelected!(ScannerType.qr);
                }
              },
            ),
            _DrawerItemTile(
              icon: Icons.view_week_rounded,
              label: 'Barcode Scanner',
              isActive: activeScreen == 'barcode_scanner',
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (_isPushedScreen) {
                  Navigator.pop(context, ScannerType.barcode);
                } else if (onScannerTypeSelected != null) {
                  onScannerTypeSelected!(ScannerType.barcode);
                }
              },
            ),
            _DrawerItemTile(
              icon: Icons.qr_code_rounded,
              label: 'Generator',
              isActive: activeScreen == 'generator',
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (activeScreen == 'generator') return;
                
                if (_isPushedScreen) {
                  Navigator.pop(context, 'generator');
                } else {
                  if (onGeneratorSelected != null) {
                    onGeneratorSelected!();
                  }
                }
              },
            ),
            _DrawerItemTile(
              icon: Icons.history_rounded,
              label: 'History',
              isActive: activeScreen == 'history',
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (activeScreen == 'history') return;

                if (_isPushedScreen) {
                  Navigator.pop(context, 'history');
                } else {
                  if (onHistoryTap != null) onHistoryTap!();
                }
              },
            ),
            _DrawerItemTile(
              icon: Icons.star_rounded,
              label: 'Favourites',
              isActive: activeScreen == 'favourites',
              onTap: () {
                Navigator.pop(context); // Close drawer
                if (activeScreen == 'favourites') return;

                if (_isPushedScreen) {
                  Navigator.pop(context, 'favourites');
                } else {
                  if (onFavouritesTap != null) onFavouritesTap!();
                }
              },
            ),
            
            // Visual separator for action items
            // const Padding(
            //   padding: EdgeInsets.symmetric(vertical: 8.0),
            //   child: Divider(
            //     color: AppColors.border,
            //     height: 1,
            //     thickness: 0.5,
            //   ),
            // ),
            
            _DrawerItemTile(
              icon: Icons.share_rounded,
              label: 'Share',
              isActive: false,
              onTap: () {
                Navigator.pop(context); // Close drawer first
                Share.share(_kShareText);
              },
            ),
            _DrawerItemTile(
              icon: Icons.apps_rounded,
              label: 'Other Apps',
              isActive: false,
              onTap: () async {
                Navigator.pop(context); // Close drawer first
                final uri = Uri.parse(_kDeveloperPageUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code_2,
                color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Scan', style: AppTextStyles.drawerHeader),
        ],
      ),
    );
  }
}

class _DrawerItemTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItemTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            // bottom: BorderSide(color: Color(0xFF2A2A2A), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(label, style: AppTextStyles.drawerItem),
            if (isActive) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}