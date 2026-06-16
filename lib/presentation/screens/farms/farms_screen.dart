import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
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
    final t = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header Section ───────────────────────────────────────────────────
        Builder(builder: (context) {
          final isMobile = MediaQuery.of(context).size.width.isMobile;
          if (isMobile) {
            return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Icon(Icons.agriculture_rounded, color: AppColors.greenMid, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Farm Management',
                    style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Sora')),
                Text('Manage your farms',
                    style: t.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontFamily: 'Sora')),
              ])),
              AddButton(label: '+ Farm', onTap: () => showFarmFormDialog(context, ref)),
            ]);
          }
          return Row(children: [
            const Icon(Icons.agriculture_rounded, color: AppColors.greenMid, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Farm Management',
                  style: t.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Sora')),
              Text('Register and organize your cultivation areas',
                  style: t.labelMedium?.copyWith(
                      color: AppColors.textTertiary,
                      fontFamily: 'Sora')),
            ]),
            const Spacer(),
            AddButton(label: 'Add New Farm', onTap: () => showFarmFormDialog(context, ref)),
          ]);
        }),
        const SizedBox(height: 24),

        // ── Grid ─────────────────────────────────────────────────────────────
        if (data.farms.isEmpty)
          const Expanded(
            child: Center(
              child: EmptyState(
                icon: '🌾',
                title: 'No farms yet',
                subtitle: 'Add your first farm to start tracking harvests and markets',
              ),
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final isMobile = MediaQuery.of(context).size.width.isMobile;
              final farmWidgets = List.generate(data.farms.length, (i) {
                final farm = data.farms[i];
                final farmMandis = data.mandis.where((m) => m.farmId == farm.id).toList();
                return _FarmCard(
                  farm: farm,
                  mandis: farmMandis,
                  onEdit: () => showFarmFormDialog(context, ref, farm),
                  onDelete: () async {
                    final ok = await showConfirmDialog(context,
                        message: 'Delete "${farm.name}"? This will also remove associated markets.');
                    if (ok) ref.read(appDataProvider).deleteFarm(farm.id);
                  },
                  onAddMandi: () => showMandiFormDialog(context, ref, farm.id),
                  onDeleteMandi: (mId) async {
                    final ok = await showConfirmDialog(context, message: 'Delete this market?');
                    if (ok) ref.read(appDataProvider).deleteMandi(mId);
                  },
                );
              });

              if (isMobile) {
                return ListView.separated(
                  itemCount: farmWidgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => SizedBox(height: 320, child: farmWidgets[i]),
                );
              }

              final cols = (constraints.maxWidth / 320).floor().clamp(1, 4);
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: data.farms.length,
                itemBuilder: (_, i) => farmWidgets[i],
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
    required this.farm,
    required this.mandis,
    required this.onEdit,
    required this.onDelete,
    required this.onAddMandi,
    required this.onDeleteMandi,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.greenMid.withOpacity(0.15), AppColors.greenMid.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('🌾', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  farm.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Sora',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  AppBadge(label: farm.type, variant: BadgeVariant.green),
                  if (farm.area.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      farm.area,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                        fontFamily: 'Sora',
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
            _ActionBtn(icon: Icons.edit_rounded, onTap: onEdit, color: AppColors.greenMid),
            const SizedBox(width: 8),
            _ActionBtn(icon: Icons.delete_rounded, onTap: onDelete, color: AppColors.red, isDanger: true),
          ]),
        ),

        if (farm.address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  farm.address,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontFamily: 'Sora',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),

        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),

        // Markets Section
        Expanded(
          child: Container(
            color: AppColors.surface2.withOpacity(0.5),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONNECTED MARKETS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.08,
                        fontFamily: 'Sora',
                      ),
                    ),
                    Text(
                      '${mandis.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenMid,
                        fontFamily: 'Sora',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (mandis.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No markets linked',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textTertiary,
                          fontFamily: 'Sora',
                        ),
                      ),
                    ),
                  )
                else
                  ...mandis.map((m) => _MandiItem(m: m, onDelete: () => onDeleteMandi(m.id))),
                const SizedBox(height: 8),
                _AddMandiButton(onTap: onAddMandi),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _MandiItem extends StatelessWidget {
  final Mandi m;
  final VoidCallback onDelete;
  const _MandiItem({required this.m, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.store_rounded, size: 14, color: AppColors.greenMid),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              m.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontFamily: 'Sora',
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (m.location.isNotEmpty)
              Text(
                m.location,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                  fontFamily: 'Sora',
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ]),
        ),
        InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 14, color: AppColors.red),
          ),
        ),
      ]),
    );
  }
}

class _AddMandiButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMandiButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border2, style: BorderStyle.solid),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_rounded, size: 16, color: AppColors.textSecondary),
          SizedBox(width: 6),
          Text(
            'Link Market',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: 'Sora',
            ),
          ),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isDanger;

  const _ActionBtn({
    required this.icon,
    required this.onTap,
    required this.color,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDanger ? AppColors.red.withOpacity(0.08) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isDanger ? AppColors.red : color),
        ),
      ),
    );
  }
}