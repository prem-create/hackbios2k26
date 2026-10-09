import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'jacket_illustration.dart';

class GreetingCard extends StatelessWidget {
  final String userName;
  final String greetingText;
  final String temperatureText;
  final String tagText;

  const GreetingCard({
    super.key,
    this.userName = 'prem',
    this.greetingText = 'Greetings! How do you want to dress today?',
    this.temperatureText = '✳ 24°C',
    this.tagText = 'Casual day',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Bottom-left decorative pink circle
          Positioned(
            left: -20,
            bottom: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Bottom-right jacket graphic illustration
          Positioned(
            right: -10,
            bottom: -10,
            child: const JacketIllustration(size: 200),
          ),

          // Foreground Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Greeting Title & Weather Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $userName 👋',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withOpacity(0.06),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        temperatureText,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Subtitle
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.52,
                  child: Text(
                    greetingText,
                    style: const TextStyle(
                      color: AppColors.lightBlueText,
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom Tag Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    tagText,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
