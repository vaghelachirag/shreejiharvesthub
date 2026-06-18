import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';

class MarketsScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const MarketsScreen({super.key, this.scrollController});
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
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header Section ───────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.storefront_rounded, color: AppColors.greenMid, size: 28),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Market Directory',
                style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Sora')),
            Text('Manage your selling points and mandis',
                style: t.labelMedium?.copyWith(
                    color: AppColors.textTertiary,
                    fontFamily: 'Sora')),
          ]),
        ]),
        const SizedBox(height: 24),

        // ── Toolbar ──────────────────────────────────────────────────────────
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 300,
            child: SearchField(
              hint: 'Search markets by name or location...',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          AddButton(
            label: 'Add Market',
            onTap: () => _showMandiForm(context, null),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Grid ─────────────────────────────────────────────────────────────
        Expanded(
          child: mandis.isEmpty
              ? const Center(child: EmptyState(
                  icon: '🏪',
                  title: 'No markets found',
                  subtitle: 'Add markets to track where you sell your produce'))
              : LayoutBuilder(builder: (context, constraints) {
                  final cols = (constraints.maxWidth / 300).floor().clamp(1, 4);
                  return GridView.builder(
                    controller: widget.scrollController,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: mandis.length,
                    itemBuilder: (_, i) => _MarketCard(
                      mandi: mandis[i],
                      onEdit: () => _showMandiForm(context, mandis[i]),
                      onDelete: () async {
                        final ok = await showConfirmDialog(context,
                            message: 'Are you sure you want to delete "${mandis[i].name}"?');
                        if (ok) ref.read(appDataProvider).deleteMandi(mandis[i].id);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.greenPale,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    existing != null ? Icons.edit_note_rounded : Icons.add_business_rounded,
                    color: AppColors.greenMid,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  existing != null ? 'Edit Market Details' : 'Register New Market',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Sora'),
                ),
              ]),
              const SizedBox(height: 24),
              _fld('Market Name', TextField(
                controller: nameCtrl,
                style: _s,
                decoration: _d('e.g. APMC Jamalpur'),
                autofocus: true,
              )),
              const SizedBox(height: 16),
              _fld('Location / Address', TextField(
                controller: locCtrl,
                style: _s,
                decoration: _d('e.g. Jamalpur, Ahmedabad'),
              )),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontFamily: 'Sora')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenMid,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      final notifier = ref.read(appDataProvider);
                      final mandi = Mandi(
                        id: existing?.id ?? notifier.newId('m'),
                        farmId: '',
                        name: nameCtrl.text.trim(),
                        location: locCtrl.text.trim(),
                      );
                      if (existing != null) {
                        notifier.updateMandi(mandi);
                      } else {
                        notifier.addMandi(mandi);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(existing != null ? 'Update Market' : 'Add Market',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Sora')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fld(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.06,
                  fontFamily: 'Sora')),
          const SizedBox(height: 8),
          child,
        ],
      );

  static const _s = TextStyle(fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Sora');
  static InputDecoration _d(String h) => InputDecoration(
        hintText: h,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.greenMid, width: 1.5)),
        filled: true,
        fillColor: AppColors.surface2,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.greenMid.withOpacity(0.15), AppColors.greenMid.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.store_rounded, color: AppColors.greenMid, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mandi.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Sora',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mandi.location.isNotEmpty ? mandi.location : 'No location set',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontFamily: 'Sora',
                          fontStyle: mandi.location.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.edit_rounded,
                onTap: onEdit,
                color: AppColors.greenMid,
              ),
              const SizedBox(height: 8),
              _ActionButton(
                icon: Icons.delete_rounded,
                onTap: onDelete,
                color: AppColors.red,
                isDanger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isDanger;

  const _ActionButton({
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
