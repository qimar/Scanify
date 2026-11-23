import 'package:flutter/material.dart';
import '../../core/models/scan_record.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/services/scan_history_service.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/round_icon_button.dart';
import '../../shared/widgets/ad_banner.dart';
import '../scanner/scanner_type.dart';
import 'widgets/history_date_header.dart';
import 'widgets/history_detail_sheet.dart';
import 'widgets/history_item_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<ScanRecord> _allRecords = [];
  bool _isLoading = true;
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'Today',
    'This Week',
    'This Month',
    'QR Only',
    'Barcode Only',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await ScanHistoryService.instance.getHistory();
    if (!mounted) return;
    setState(() {
      _allRecords = history;
      _isLoading = false;
    });
  }

  List<ScanRecord> _getFilteredRecords() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _allRecords.where((record) {
      // 1. Date filters
      switch (_activeFilter) {
        case 'Today':
          final recDate = DateTime(record.scannedAt.year, record.scannedAt.month, record.scannedAt.day);
          if (recDate != today) return false;
          break;
        case 'This Week':
          final diff = now.difference(record.scannedAt).inDays;
          if (diff >= 7) return false;
          break;
        case 'This Month':
          final diff = now.difference(record.scannedAt).inDays;
          if (diff >= 30) return false;
          break;
        default:
          break;
      }
      
      // 2. Type filters
      if (_activeFilter == 'QR Only' && record.format.toLowerCase() != 'qrcode') {
        return false;
      }
      if (_activeFilter == 'Barcode Only' && record.format.toLowerCase() == 'qrcode') {
        return false;
      }
      
      return true;
    }).toList();
  }

  Map<DateTime, List<ScanRecord>> _groupRecordsByDate(List<ScanRecord> records) {
    final Map<DateTime, List<ScanRecord>> grouped = {};
    for (final record in records) {
      final date = DateTime(record.scannedAt.year, record.scannedAt.month, record.scannedAt.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(record);
    }
    return grouped;
  }

  Future<void> _showClearDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Clear History?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Favourited scans will be kept. This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ScanHistoryService.instance.clearHistory(keepFavourites: true);
                _loadHistory();
              },
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDetailSheet(ScanRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return HistoryDetailSheet(
          record: record,
          onDeleted: _loadHistory,
          onFavouriteToggled: _loadHistory,
        );
      },
    );
  }

  Future<void> _toggleFavourite(ScanRecord record) async {
    await ScanHistoryService.instance.toggleFavourite(record.id);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredRecords();
    final grouped = _groupRecordsByDate(filtered);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgDark,
      drawer: AppDrawer(
        activeScreen: 'history',
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
                  const Text('History', style: AppTextStyles.screenTitle),
                  RoundIconButton(
                    icon: Icons.delete_sweep_rounded,
                    iconColor: Colors.redAccent,
                    bgColor: AppColors.bgSurface,
                    onTap: _allRecords.isEmpty ? () {} : _showClearDialog,
                  ),
                ],
              ),
            ),

            // Horizontal Filter Chips Row
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

            // Main Listing Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: grouped.keys.length,
                          itemBuilder: (context, index) {
                            final dateKey = grouped.keys.elementAt(index);
                            final recordsForDate = grouped[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HistoryDateHeader(date: dateKey),
                                ...recordsForDate.map((record) {
                                  return HistoryItemCard(
                                    record: record,
                                    onTap: () => _showDetailSheet(record),
                                    onFavouriteToggled: () => _toggleFavourite(record),
                                  );
                                }).toList(),
                              ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No scans yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
