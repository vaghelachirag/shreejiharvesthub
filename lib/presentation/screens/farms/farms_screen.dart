import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'farm_form_dialog.dart';
import '../sales/sale_form_dialog.dart';

class FarmsScreen extends ConsumerWidget {
  const FarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('FARMS & MARKETS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary, letterSpacing: 0.08)),
          const Spacer(),
          AddButton(label: '＋ Add Farm', onTap: () => showFarmFormDialog(context, ref)),
        ]),
        const SizedBox(height: 16),
        if (data.farms.isEmpty)
          const Center(child: EmptyState(icon: '🌾', title: 'No farms yet', subtitle: 'Add your first farm to get started'))
        else
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final cols = (constraints.maxWidth / 290).floor().clamp(1, 4);
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: data.farms.length,
                itemBuilder: (_, i) {
                  final farm = data.farms[i];
                  final farmMandis = data.mandis.where((m) => m.farmId == farm.id).toList();
                  return _FarmCard(
                    farm: farm,
                    mandis: farmMandis,
                    onEdit: () => showFarmFormDialog(context, ref, farm),
                    onDelete: () async {
                      final ok = await showConfirmDialog(context,
                          message: 'Delete "${farm.name}"? This will also remove associated markets.');
                      if (ok) ref.read(appDataProvider.notifier).deleteFarm(farm.id);
                    },
                    onAddMandi: () => showMandiFormDialog(context, ref, farm.id),
                    onDeleteMandi: (mId) async {
                      final ok = await showConfirmDialog(context, message: 'Delete this market?');
                      if (ok) ref.read(appDataProvider.notifier).deleteMandi(mId);
                    },
                  );
                },
              );
            }),
          ),
      ]),
    );
  }
}

// ── FARM CARD ─────────────────────────────────────────────────────────────────
class _FarmCard extends StatelessWidget {
  final Farm farm;
  final List<Mandi> mandis;
  final VoidCallback onEdit, onDelete, onAddMandi;
  final ValueChanged<String> onDeleteMandi;

  const _FarmCard({
    required this.farm, required this.mandis,
    required this.onEdit, required this.onDelete,
    required this.onAddMandi, required this.onDeleteMandi,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.greenPale, Color(0xFFC9E6A0)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('🌾', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(farm.name, style: t.titleMedium?.copyWith(fontSize: 15)),
              Row(children: [
                AppBadge(label: farm.type, variant: BadgeVariant.green),
                if (farm.area.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(farm.area, style: t.labelSmall?.copyWith(color: AppColors.textTertiary)),
                ],
              ]),
            ])),
            ActionIconButton(icon: Icons.edit_outlined, onTap: onEdit, isDanger: false),
            const SizedBox(width: 4),
            ActionIconButton(icon: Icons.delete_outline, onTap: onDelete, isDanger: true),
          ]),
          if (farm.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(child: Text(farm.address,
                  style: t.labelSmall?.copyWith(color: AppColors.textTertiary),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          // Markets
          Text('MARKETS', style: t.labelMedium?.copyWith(
              color: AppColors.textTertiary, fontSize: 10, letterSpacing: 0.08)),
          const SizedBox(height: 6),
          ...mandis.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  if (m.location.isNotEmpty)
                    Text(m.location, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ])),
                ActionIconButton(icon: Icons.close, onTap: () => onDeleteMandi(m.id), isDanger: true),
              ]),
            ),
          )),
          const SizedBox(height: 4),
          InkWell(
            onTap: onAddMandi,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.border2,
                    style: BorderStyle.solid),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Text('Add Market', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
