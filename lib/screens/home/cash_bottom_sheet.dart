import 'package:flutter/material.dart';
import 'package:ride_sharing_app/utils/app_colors.dart';

class CashBottomSheet extends StatelessWidget {
  final String selectedPaymentMethod;

  CashBottomSheet({this.selectedPaymentMethod = 'Cash'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment methods',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).hintColor),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16.0),

          // Payment Method Options
          PaymentOptionTile(
            icon: Icons.money,
            title: 'Cash',
            isSelected: selectedPaymentMethod == 'Cash',
            onTap: () {
              // Handle "Cash" selection
              Navigator.pop(context, 'Cash');
            },
          ),
          PaymentOptionTile(
            icon: Icons.account_balance_wallet,
            title: 'JazzCash',
            isSelected: selectedPaymentMethod == 'JazzCash',
            onTap: () {
              // Handle "JazzCash" selection
              Navigator.pop(context, 'JazzCash');
            },
          ),
          PaymentOptionTile(
            icon: Icons.account_balance_wallet,
            title: 'EasyPaisa',
            isSelected: selectedPaymentMethod == 'EasyPaisa',
            onTap: () {
              // Handle "EasyPaisa" selection
              Navigator.pop(context, 'EasyPaisa');
            },
          ),
        ],
      ),
    );
  }
}

// Helper widget for individual payment options
class PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  PaymentOptionTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary.value : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected? AppColors.white: Theme.of(context).hintColor),
            SizedBox(width: 16.0),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: isSelected? AppColors.white : Theme.of(context).hintColor, fontSize: 16.0),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: AppColors.white), // Check icon for selected option
          ],
        ),
      ),
    );
  }
}
