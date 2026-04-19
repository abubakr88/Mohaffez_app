import 'package:flutter/material.dart';

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
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
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
                color: Colors.grey,
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
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'محفظة',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
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
        Icon(icon, color: Colors.green.shade700, size: 28),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodIcon(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Image.asset(
        assetPath,
        height: 24,
        width: 40,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 24,
          color: Colors.grey.shade200,
          child: const Icon(Icons.credit_card, size: 16),
        ),
      ),
    );
  }
}
