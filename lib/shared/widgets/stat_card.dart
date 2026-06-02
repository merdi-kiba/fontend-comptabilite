import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final String? trend;
  final bool? trendPositive;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.iconColor,
    this.iconBg,
    this.trend,
    this.trendPositive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.primary;
    final effectiveIconBg = iconBg ?? AppColors.primary.withValues(alpha: 0.1);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: effectiveIconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: effectiveIconColor, size: 22),
                  ),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (trendPositive ?? true)
                            ? AppColors.positive.withValues(alpha: 0.1)
                            : AppColors.negative.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (trendPositive ?? true) ? Icons.trending_up : Icons.trending_down,
                            size: 12,
                            color: (trendPositive ?? true) ? AppColors.positive : AppColors.negative,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trend!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: (trendPositive ?? true) ? AppColors.positive : AppColors.negative,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Version shimmer pour le chargement
class StatCardShimmer extends StatelessWidget {
  const StatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _shimmerBox(44, 44, radius: 10),
                _shimmerBox(60, 24, radius: 20),
              ],
            ),
            const SizedBox(height: 16),
            _shimmerBox(120, 28),
            const SizedBox(height: 8),
            _shimmerBox(80, 14),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {double radius = 4}) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
