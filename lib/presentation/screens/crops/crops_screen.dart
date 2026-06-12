import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';

class CropsScreen extends ConsumerStatefulWidget {
  const CropsScreen({super.key});
  @override
  ConsumerState<CropsScreen> createState() => _State();
}

class _State extends ConsumerState<CropsScreen> {
  String _search = '', _farmFilter = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);

    var crops = data.crops.where((c) {
      if (_farmFilter.isNotEmpty && c.farmId != _farmFilter) return false;
      if (_search.isNotEmpty && !c.name.toLowerCase().contains(_search.toLowerCase())) return false;
      return true;
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search crop...', onChanged: (v) => setState(() => _search = v)),
          FilterDropdown(
            value: _farmFilter.isEmpty ? '' : _farmFilter,
            items: [
              const DropdownMenuItem(value: '', child: Text('All Farms')),
              ...data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
            ],
            onChanged: (v) => setState(() => _farmFilter = v ?? ''),
          ),
          AddButton(label: '＋ Add Crop', onTap: () => _showCropForm(context, null)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: crops.isEmpty
              ? const Center(child: EmptyState(icon: '🌱', title: 'No crops yet', subtitle: 'Add your first crop'))
              : LayoutBuilder(builder: (context, constraints) {
            final cols = (constraints.maxWidth / 290).floor().clamp(1, 4);
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: 1.65,
              ),
              itemCount: crops.length,
              itemBuilder: (_, i) => _CropCard(
                crop: crops[i],
                farmName: AppUtils.farmName(data.farms, crops[i].farmId),
                onEdit: () => _showCropForm(context, crops[i]),
                onDelete: () async {
                  final ok = await showConfirmDialog(context, message: 'Delete crop "${crops[i].name}"?');
                  if (ok) ref.read(appDataProvider).deleteCrop(crops[i].id);
                },
              ),
            );
          }),
        ),
      ]),
    );
  }

  void _showCropForm(BuildContext context, Crop? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final startCtrl = TextEditingController(text: existing?.start ?? '');
    final endCtrl = TextEditingController(text: existing?.end ?? '');
    String farmId = existing?.farmId ?? '';
    final data = ref.read(appDataProvider);
    if (farmId.isEmpty && data.farms.isNotEmpty) farmId = data.farms.first.id;

    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setState) => Dialog(
      child: Container(
        width: 480, padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing != null ? 'Edit Crop' : 'Add Crop',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 18),
          _fld('Crop Name', TextField(controller: nameCtrl, style: _s, decoration: _d('e.g. Tomato, Wheat...'))),
          const SizedBox(height: 10),
          _fld('Farm', Container(
            height: 40, padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border2, width: 1.5)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: farmId.isEmpty ? null : farmId,
              hint: const Text('Select farm', style: _hs),
              items: data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: _s))).toList(),
              onChanged: (v) => setState(() => farmId = v ?? farmId),
              dropdownColor: AppColors.surface, isExpanded: true, isDense: true,
            )),
          )),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _fld('Start Date', _DatePickerField(
              controller: startCtrl,
              hint: 'YYYY-MM-DD',
              onPick: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: _parseDate(startCtrl.text) ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  startCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                }
              },
            ))),
            const SizedBox(width: 10),
            Expanded(child: _fld('End Date', _DatePickerField(
              controller: endCtrl,
              hint: 'YYYY-MM-DD',
              onPick: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: _parseDate(endCtrl.text) ?? _parseDate(startCtrl.text) ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  endCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                }
              },
            ))),
          ]),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.only(top: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  if (nameCtrl.text.trim().isEmpty || farmId.isEmpty) return;
                  final notifier = ref.read(appDataProvider);
                  final crop = Crop(
                    id: existing?.id ?? notifier.newId('c'),
                    farmId: farmId, name: nameCtrl.text.trim(),
                    start: startCtrl.text.trim(), end: endCtrl.text.trim(),
                  );
                  if (existing != null) notifier.updateCrop(crop); else notifier.addCrop(crop);
                  Navigator.pop(ctx);
                }, child: const Text('Save')),
              ])),
        ]),
      ),
    )));
  }

  Widget _fld(String label, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.04)),
        const SizedBox(height: 4), child,
      ]);

  DateTime? _parseDate(String v) {
    try { return v.length == 10 ? DateTime.parse(v) : null; } catch (_) { return null; }
  }

  static const _s = TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');
  static const _hs = TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora');
  static InputDecoration _d(String h) => InputDecoration(
    hintText: h, hintStyle: _hs,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5)),
    filled: true, fillColor: AppColors.surface2,
  );
}

// ── DATE PICKER FIELD ─────────────────────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onPick;

  const _DatePickerField({required this.controller, required this.hint, required this.onPick});

  static const _s = TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');
  static const _hs = TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora');

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: _s,
      readOnly: true,
      onTap: onPick,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _hs,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        suffixIcon: GestureDetector(
          onTap: onPick,
          child: const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5)),
        filled: true,
        fillColor: AppColors.surface2,
      ),
    );
  }
}

// ── CROP CARD ─────────────────────────────────────────────────────────────────
class _CropCard extends StatelessWidget {
  final Crop crop;
  final String farmName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CropCard({required this.crop, required this.farmName,
    required this.onEdit, required this.onDelete});

  static const _cropEmojis = {'tomato': '🍅', 'okra': '🥦', 'cabbage': '🥬',
    'brinjal': '🍆', 'wheat': '🌾', 'rice': '🌾', 'potato': '🥔',
    'onion': '🧅', 'carrot': '🥕', 'corn': '🌽'};

  String get _emoji {
    final key = crop.name.toLowerCase();
    return _cropEmojis.entries
        .firstWhere((e) => key.contains(e.key), orElse: () => const MapEntry('', '🌿'))
        .value;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final status = AppUtils.cropStatusLabel(crop.start, crop.end);
    Color leftBar;
    switch (status) {
      case 'active': leftBar = AppColors.greenLight; break;
      case 'done': leftBar = AppColors.textTertiary; break;
      default: leftBar = AppColors.amber;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Stack(children: [
        // Left accent bar
        Positioned(left: 0, top: 0, bottom: 0,
            child: Container(width: 4, decoration: BoxDecoration(
              color: leftBar,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            ))),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.greenPale, Color(0xFFC9E6A0)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(crop.name, style: t.titleMedium),
                Text(farmName, style: t.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 12)),
              ])),
              // Actions
              Row(mainAxisSize: MainAxisSize.min, children: [
                ActionIconButton(icon: Icons.edit_outlined, onTap: onEdit, isDanger: false),
                const SizedBox(width: 4),
                ActionIconButton(icon: Icons.delete_outline, onTap: onDelete, isDanger: true),
              ]),
            ]),
            const SizedBox(height: 10),
            // Status badge
            _StatusBadge(status: status),
            const SizedBox(height: 10),
            // Dates
            Row(children: [
              Expanded(child: _DateBox(label: 'SOWN', value: crop.start.isNotEmpty ? AppUtils.formatDate(crop.start) : '—')),
              const SizedBox(width: 8),
              Expanded(child: _DateBox(label: 'HARVEST', value: crop.end.isNotEmpty ? AppUtils.formatDate(crop.end) : '—')),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    IconData icon;
    switch (status) {
      case 'active': bg = AppColors.greenPale; fg = AppColors.greenMid; label = '● Active'; icon = Icons.circle; break;
      case 'done': bg = AppColors.surface2; fg = AppColors.textTertiary; label = '✓ Done'; icon = Icons.check; break;
      default: bg = AppColors.amberPale; fg = AppColors.amber; label = '◷ Upcoming'; icon = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _DateBox extends StatelessWidget {
  final String label;
  final String value;
  const _DateBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: AppColors.textTertiary, letterSpacing: 0.05)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary, fontFamily: 'monospace')),
      ]),
    );
  }
}