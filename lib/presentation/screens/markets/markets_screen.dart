import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});
  @override
  ConsumerState<MarketsScreen> createState() => _State();
}

class _State extends ConsumerState<MarketsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final t = Theme.of(context).textTheme;

    var mandis = data.mandis.where((m) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return m.name.toLowerCase().contains(q) || m.location.toLowerCase().contains(q);
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Toolbar
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search market...', onChanged: (v) => setState(() => _search = v)),
          const Spacer(),
          AddButton(label: '＋ Add Market', onTap: () => _showMandiForm(context, null)),
        ]),
        const SizedBox(height: 16),
        // Grid
        Expanded(
          child: mandis.isEmpty
              ? const Center(child: EmptyState(icon: '🏪', title: 'No markets yet', subtitle: 'Add your first market'))
              : LayoutBuilder(builder: (context, constraints) {
                  final cols = (constraints.maxWidth / 260).floor().clamp(1, 4);
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14, mainAxisSpacing: 14,
                      childAspectRatio: 2.0,
                    ),
                    itemCount: mandis.length,
                    itemBuilder: (_, i) => _MarketCard(
                      mandi: mandis[i],
                      onEdit: () => _showMandiForm(context, mandis[i]),
                      onDelete: () async {
                        final ok = await showConfirmDialog(context,
                            message: 'Delete market "${mandis[i].name}"?');
                        if (ok) ref.read(appDataProvider.notifier).deleteMandi(mandis[i].id);
                      },
                    ),
                  );
                }),
        ),
      ]),
    );
  }

  void _showMandiForm(BuildContext context, Mandi? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          width: 420, padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(existing != null ? 'Edit Market' : 'Add Market',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            _fld('Market Name', TextField(controller: nameCtrl, style: _s, decoration: _d('e.g. APMC Jamalpur'))),
            const SizedBox(height: 10),
            _fld('Location', TextField(controller: locCtrl, style: _s, decoration: _d('e.g. Jamalpur, Ahmedabad'))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final notifier = ref.read(appDataProvider.notifier);
                  final mandi = Mandi(
                    id: existing?.id ?? notifier.newId('m'),
                    farmId: '',
                    name: nameCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                  );
                  if (existing != null) notifier.updateMandi(mandi);
                  else notifier.addMandi(mandi);
                  Navigator.pop(context);
                }, child: const Text('Save')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fld(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
    children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 0.04)),
      const SizedBox(height: 4), child,
    ]);

  static const _s = TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');
  static InputDecoration _d(String h) => InputDecoration(
    hintText: h,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5)),
    filled: true, fillColor: AppColors.surface2,
  );
}

// ── MARKET CARD ───────────────────────────────────────────────────────────────
class _MarketCard extends StatelessWidget {
  final Mandi mandi;
  final VoidCallback onEdit, onDelete;
  const _MarketCard({required this.mandi, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.greenPale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(child: Text('🏪', style: TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(mandi.name,
                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
            if (mandi.location.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textTertiary),
                const SizedBox(width: 3),
                Expanded(child: Text(mandi.location,
                    style: t.labelSmall?.copyWith(color: AppColors.textTertiary),
                    overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ],
        )),
        const SizedBox(width: 8),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ActionIconButton(icon: Icons.edit_outlined, onTap: onEdit),
          const SizedBox(height: 4),
          ActionIconButton(icon: Icons.delete_outline, onTap: onDelete, isDanger: true),
        ]),
      ]),
    );
  }
}
