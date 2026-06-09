import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';

Future<void> showFarmFormDialog(BuildContext context, WidgetRef ref, [Farm? existing]) async {
  await showDialog(
    context: context,
    builder: (_) => _FarmFormDialog(existing: existing, ref: ref),
  );
}

class _FarmFormDialog extends ConsumerStatefulWidget {
  final Farm? existing;
  final WidgetRef ref;
  const _FarmFormDialog({this.existing, required this.ref});
  @override
  ConsumerState<_FarmFormDialog> createState() => _State();
}

class _State extends ConsumerState<_FarmFormDialog> {
  final _nameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  String _type = 'Vegetable';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _areaCtrl.text = widget.existing!.area;
      _addrCtrl.text = widget.existing!.address;
      _type = widget.existing!.type;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _areaCtrl.dispose(); _addrCtrl.dispose(); super.dispose(); }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final notifier = ref.read(appDataProvider);
    final farm = Farm(
      id: widget.existing?.id ?? notifier.newId('f'),
      name: _nameCtrl.text.trim(),
      type: _type,
      area: _areaCtrl.text.trim(),
      address: _addrCtrl.text.trim(),
    );
    if (widget.existing != null) notifier.updateFarm(farm); else notifier.addFarm(farm);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(child: Container(
      width: 480, padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing != null ? 'Edit Farm' : 'Add Farm',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 18),
        _fld('Farm Name', TextField(controller: _nameCtrl, style: _s, decoration: _d('e.g. Jamalpur Farm'))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _fld('Type', Container(
            height: 40, padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border2, width: 1.5)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _type,
              items: AppConstants.farmTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: _s.copyWith(fontWeight: FontWeight.w700)))).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
              dropdownColor: AppColors.surface, isExpanded: true, isDense: true,
              style: _s.copyWith(fontWeight: FontWeight.w700),
            )),
          ))),
          const SizedBox(width: 10),
          Expanded(child: _fld('Area', TextField(controller: _areaCtrl, style: _s, decoration: _d('e.g. 3 acres')))),
        ]),
        const SizedBox(height: 10),
        _fld('Address / Location', TextField(controller: _addrCtrl, style: _s, decoration: _d('Enter address or location'))),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.only(top: 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ])),
      ]),
    ));
  }

  Widget _fld(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 0.04)),
      const SizedBox(height: 4), child,
    ]);

  static const _s = TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');
  static InputDecoration _d(String h) => InputDecoration(
    hintText: h,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora'),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5)),
    filled: true, fillColor: AppColors.surface2,
  );
}
