import 'package:flutter/material.dart';
import 'package:mohaffez_finder_app/shared/theme/app_theme_constants.dart';

class TrustBadgesWidget extends StatelessWidget {
  final bool showPaymentMethods;
  
  const TrustBadgesWidget({
    super.key,
    this.showPaymentMethods = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeConstants.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeConstants.accentGreenAlt),
      ),
      child: Column(
        children: [
          // Trust Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTrustItem(
                Icons.lock,
                'دفع آمن',
                'تشفير 256-bit',
              ),
              _buildTrustItem(
                Icons.verified_user,
                'معتمد',
                'موثق ومضمون',
              ),
              _buildTrustItem(
                Icons.replay,
                'استرجاع',
                'خلال ساعتين',
              ),
            ],
          ),
          
          if (showPaymentMethods) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Payment Methods
            const Text(
              'طرق الدفع المتاحة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppThemeConstants.grey500,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPaymentMethodIcon('assets/images/visa.png'),
                const SizedBox(width: 12),
                _buildPaymentMethodIcon('assets/images/mastercard.png'),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeConstants.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: AppThemeConstants.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'محفظة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppThemeConstants.warning,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, color: AppThemeConstants.success, size: 28),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppThemeConstants.success,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 10,
            color: AppThemeConstants.grey600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodIcon(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppThemeConstants.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppThemeConstants.grey300),
      ),
      child: Image.asset(
        assetPath,
        height: 24,
        width: 40,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 24,
          color: AppThemeConstants.grey200,
          child: const Icon(Icons.credit_card, size: 16),
        ),
      ),
    );
  }
}
