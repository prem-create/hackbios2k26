import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final Widget? actionWidget;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBackTap,
    this.actionWidget,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                showBackButton ? Icons.arrow_back_rounded : Icons.menu_rounded,
                color: AppColors.navy,
                size: 24,
              ),
              onPressed: showBackButton
                  ? (onBackTap ?? () => Get.back())
                  : () => Scaffold.of(context).openDrawer(),
              tooltip: showBackButton ? 'Back' : 'Menu',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (actionWidget != null) actionWidget!,
        ],
      ),
    );
  }
}
