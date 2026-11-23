import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'core/providers/ad_provider/ads_provider.dart';
import 'features/scanner/scanner_screen.dart';

class QRScannerApp extends StatelessWidget {
  const QRScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdProvider>(
      create: (_) => AdProvider()..loadAdsOnFirstUse(),
      child: MaterialApp(
        title: 'QR Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bgDark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.bgSurface,
          ),
          useMaterial3: true,
        ),
        home: const ScannerScreen(),
      ),
    );
  }
}
