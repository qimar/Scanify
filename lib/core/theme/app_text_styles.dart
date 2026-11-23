import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static const bodyLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    height: 1.5,
  );

  static const bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    letterSpacing: 0.2,
  );

  static const label = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 13,
  );

  static const drawerItem = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static const drawerHeader = TextStyle(
    color: AppColors.primary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const buttonLabel = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}
