import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/emcf/tabs/emcf_compliance_tab.dart';
import 'package:proxima/features/emcf/tabs/emcf_edefs_tab.dart';
import 'package:proxima/features/emcf/tabs/emcf_queue_tab.dart';
import 'package:proxima/features/emcf/tabs/emcf_config_tab.dart';
import 'package:proxima/features/emcf/tabs/emcf_referentiels_tab.dart';

class EmcfScreen extends ConsumerWidget {
  const EmcfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Conformité'),
                Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'EDEFs'),
                Tab(icon: Icon(Icons.queue_outlined, size: 18), text: 'File d\'attente'),
                Tab(icon: Icon(Icons.vpn_key_outlined, size: 18), text: 'Configuration'),
                Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: 'Référentiels'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                EmcfComplianceTab(),
                EmcfEdefsTab(),
                EmcfQueueTab(),
                EmcfConfigTab(),
                EmcfReferentielsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
