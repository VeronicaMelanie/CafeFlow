import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_providers.dart';

import '../constants/app_colors.dart';

import '../theme/app_spacing.dart';

import 'app_skeleton.dart';



class AdminGuard extends ConsumerWidget {

  final Widget child;



  const AdminGuard({super.key, required this.child});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final currentUser = ref.watch(currentUserProvider);



    return currentUser.when(

      data: (userModel) {

        if (userModel == null) {

          return const Scaffold(body: AppLoadingIndicator());

        }



        if (!userModel.isAdmin) {

          return Scaffold(

            backgroundColor: AppColors.offWhite,

            body: Center(

              child: Padding(

                padding: const EdgeInsets.all(AppSpacing.xxxl),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Container(

                      padding: const EdgeInsets.all(AppSpacing.xl),

                      decoration: BoxDecoration(

                        color: AppColors.softPink.withValues(alpha: 0.5),

                        shape: BoxShape.circle,

                      ),

                      child: Icon(

                        Icons.lock_outline_rounded,

                        size: 40,

                        color: AppColors.primaryPink.withValues(alpha: 0.7),

                      ),

                    ),

                    const SizedBox(height: AppSpacing.lg),

                    Text(

                      'Admin access required',

                      style: Theme.of(context).textTheme.headlineSmall,

                    ),

                    const SizedBox(height: AppSpacing.sm),

                    Text(

                      'Your account does not have permission to open this screen.',

                      textAlign: TextAlign.center,

                      style: Theme.of(context).textTheme.bodyMedium,

                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    ElevatedButton(

                      onPressed: () => Navigator.of(context).maybePop(),

                      child: const Text('Back'),

                    ),

                  ],

                ),

              ),

            ),

          );

        }



        return child;

      },

      loading: () => const Scaffold(body: AppLoadingIndicator()),

      error: (e, st) => Scaffold(

        body: Center(child: Text('Error: $e')),

      ),

    );

  }

}


