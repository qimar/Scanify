import 'package:flutter/material.dart';
import '../../core/models/scan_record.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/scan_history_service.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/round_icon_button.dart';
import '../../shared/widgets/ad_banner.dart';
import '../scanner/scanner_type.dart';
import '../history/widgets/history_detail_sheet.dart';
import 'widgets/favourites_item_card.dart';

class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<ScanRecord> _favourites = [];
  bool _isLoading = true;
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'QR Only',
    'Barcode Only',
  ];

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final favs = await ScanHistoryService.instance.getFavourites();
    if (!mounted) return;
    setState(() {
      _favourites = favs;
      _isLoading = false;
    });
  }

  List<ScanRecord> _getFilteredFavourites() {
    return _favourites.where((record) {
      if (_activeFilter == 'QR Only' && record.format.toLowerCase() != 'qrcode') {
        return false;
      }
      if (_activeFilter == 'Barcode Only' && record.format.toLowerCase() == 'qrcode') {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _unfavourite(ScanRecord record) async {
    // Optimistic update
    setState(() {
      _favourites.removeWhere((r) => r.id == record.id);
    });
    await ScanHistoryService.instance.toggleFavourite(record.id);
    // Reload in case of any sync discrepancy, though optimistic update handles UI
    _loadFavourites();
  }

  void _showDetailSheet(ScanRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return HistoryDetailSheet(
          record: record,
          onDeleted: _loadFavourites,
          onFavouriteToggled: _loadFavourites,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredFavourites();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgDark,
      drawer: AppDrawer(
        activeScreen: 'favourites',
        activeScannerType: ScannerType.qr,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RoundIconButton(
                    icon: Icons.menu_rounded,
                    bgColor: AppColors.bgSurface,
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Text('Favourites', style: AppTextStyles.screenTitle),
                  const SizedBox(width: 40), // Balance drawer button size
                ],
              ),
            ),

            // Filter Chips
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isActive = _activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeFilter = filter;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? AppColors.primary : AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Favourites List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final record = filtered[index];
                            return FavouritesItemCard(
                              record: record,
                              onTap: () => _showDetailSheet(record),
                              onUnfavourite: () => _unfavourite(record),
                            );
                          },
                        ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.star_rounded,
              size: 64,
              color: const Color(0xFFFBBF24).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No favourites yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap ★ on any scan to save it here',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
