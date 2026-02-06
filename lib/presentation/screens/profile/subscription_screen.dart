import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../widgets/widgets.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
              return;
            }
            context.go('/settings');
          },
        ),
        elevation: 0,
        title: Text(
          'Subscription',
          style: AppTypography.subtitle1.copyWith(color: colorScheme.onSurface),
        ),
      ),
      
      body: ListView(
        padding: AppSpacing.paddingLarge,
        children: [
          // Current Plan
          _buildCurrentPlan(context),
          
          SizedBox(height: AppSpacing.xxxl),
          
          // Available Plans
          Text(
            'Available Plans',
            style: AppTypography.subtitle2.copyWith(color: colorScheme.onSurface),
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          _buildPlanCard(
            context,
            'Free',
            'Perfect for getting started',
            0.0,
            [
              '3 game generations per month',
              'Basic templates',
              'Community support',
              'Standard builds',
            ],
            isCurrent: false,
            isPopular: false,
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          _buildPlanCard(
            context,
            'Pro',
            'Best for serious creators',
            9.99,
            [
              'Unlimited game generations',
              'Premium templates',
              'Priority support',
              'Advanced AI features',
              'Custom assets',
              'Multi-platform builds',
            ],
            isCurrent: true,
            isPopular: true,
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          _buildPlanCard(
            context,
            'Enterprise',
            'For teams and businesses',
            29.99,
            [
              'Everything in Pro',
              'Team collaboration',
              'White-label options',
              'API access',
              'Dedicated support',
              'Custom integrations',
            ],
            isCurrent: false,
            isPopular: false,
          ),
          
          SizedBox(height: AppSpacing.xxxl),
          
          // Payment Method
          _buildPaymentMethod(context),
          
          SizedBox(height: AppSpacing.xxxl),
          
          // Billing History
          _buildBillingHistory(context),
          
          SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildCurrentPlan(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.10),
            colorScheme.secondary.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: colorScheme.primary.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium,
                color: colorScheme.primary,
              ),
              
              SizedBox(width: AppSpacing.md),
              
              Text(
                'Current Plan: Pro',
                style: AppTypography.subtitle2.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              
              const Expanded(
                child: SizedBox(),
              ),
              
              StatusBadge(
                text: 'Active',
                color: AppColors.success,
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.md),
          
          Text(
            '\$9.99/month',
            style: AppTypography.h3.copyWith(
              color: colorScheme.primary,
            ),
          ),
          
          SizedBox(height: AppSpacing.sm),
          
          Text(
            'Renews on December 1, 2024',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          CustomButton(
            text: 'Cancel Subscription',
            onPressed: () => _showCancelDialog(context),
            type: ButtonType.danger,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    String name,
    String description,
    double price,
    List<String> features, {
    bool isCurrent = false,
    bool isPopular = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: isCurrent ? colorScheme.primary : colorScheme.outline.withOpacity(0.5),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isPopular ? colorScheme.primary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.large),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTypography.subtitle1.copyWith(
                        color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    if (isPopular) ...[
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: AppBorderRadius.allSmall,
                        ),
                        child: Text(
                          'POPULAR',
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                SizedBox(height: AppSpacing.sm),
                
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: AppSpacing.md),
                
                Text(
                  price == 0.0 ? 'Free' : '\$${price.toStringAsFixed(2)}/month',
                  style: AppTypography.h3.copyWith(
                    color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          
          // Features
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: features.map((feature) {
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                      
                      SizedBox(width: AppSpacing.md),
                      
                      Expanded(
                        child: Text(
                          feature,
                          style: AppTypography.body2.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Action button
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CustomButton(
              text: isCurrent ? 'Current Plan' : 'Upgrade to $name',
              onPressed: isCurrent ? null : () => _upgradePlan(context, name),
              type: isCurrent ? ButtonType.ghost : ButtonType.primary,
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payment Method',
                style: AppTypography.subtitle2.copyWith(color: colorScheme.onSurface),
              ),
              
              const Expanded(
                child: SizedBox(),
              ),
              
              TextButton(
                onPressed: () {
                  // TODO: Navigate to payment methods
                },
                child: Text(
                  'Change',
                  style: AppTypography.body2.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.credit_card,
                  color: colorScheme.primary,
                ),
                
                SizedBox(width: AppSpacing.lg),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visa ending in 4242',
                        style: AppTypography.body2.copyWith(color: colorScheme.onSurface),
                      ),
                      
                      SizedBox(height: AppSpacing.xs),
                      
                      Text(
                        'Expires 12/25',
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingHistory(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final billingHistory = [
      BillingItem(
        date: 'November 1, 2024',
        description: 'Pro Plan Subscription',
        amount: 9.99,
        status: 'Paid',
      ),
      BillingItem(
        date: 'October 1, 2024',
        description: 'Pro Plan Subscription',
        amount: 9.99,
        status: 'Paid',
      ),
      BillingItem(
        date: 'September 1, 2024',
        description: 'Pro Plan Subscription',
        amount: 9.99,
        status: 'Paid',
      ),
    ];
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Billing History',
                style: AppTypography.subtitle2.copyWith(color: colorScheme.onSurface),
              ),
              
              const Expanded(
                child: SizedBox(),
              ),
              
              TextButton(
                onPressed: () {
                  // TODO: Navigate to full billing history
                },
                child: Text(
                  'View All',
                  style: AppTypography.body2.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          ...billingHistory.map((item) => _buildBillingItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildBillingItem(BuildContext context, BillingItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: AppTypography.body2.copyWith(color: colorScheme.onSurface),
                ),
                
                SizedBox(height: AppSpacing.xs),
                
                Text(
                  item.date,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${item.amount.toStringAsFixed(2)}',
                style: AppTypography.body2.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: AppSpacing.xs),
              
              StatusBadge(
                text: item.status,
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _upgradePlan(BuildContext context, String planName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade to $planName'),
        content: Text('Are you sure you want to upgrade to the $planName plan?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upgraded to $planName successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? You will lose access to all Pro features at the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Subscription cancelled. You can reactivate anytime.'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            child: Text(
              'Cancel Anyway',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class BillingItem {
  final String date;
  final String description;
  final double amount;
  final String status;

  BillingItem({
    required this.date,
    required this.description,
    required this.amount,
    required this.status,
  });
}
