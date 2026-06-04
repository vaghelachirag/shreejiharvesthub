import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';

Future<void> showSaleFormDialog(
    BuildContext context, WidgetRef ref, [Sale? existing]) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => _SaleFormDialog(existing: existing, outerRef: ref),
  );
}

// ── BREAKDOWN ROW STATE ───────────────────────────────────────────────────────
class _BdRow {
  final TextEditingController qty;
  final TextEditingController rate;
  _BdRow()
      : qty = TextEditingController(),
        rate = TextEditingController();
  double get sub {
    final q = double.tryParse(qty.text) ?? 0;
    final r = double.tryParse(rate.text) ?? 0;
    return q * r;
  }
  void dispose() {
    qty.dispose();
    rate.dispose();
  }
}

// ── DIALOG ────────────────────────────────────────────────────────────────────
class _SaleFormDialog extends ConsumerStatefulWidget {
  final Sale? existing;
  final WidgetRef outerRef;
  const _SaleFormDialog({this.existing, required this.outerRef});

  @override
  ConsumerState<_SaleFormDialog> createState() => _State();
}

class _State extends ConsumerState<_SaleFormDialog> {
  final _buyerCtrl = TextEditingController();
  final _overrideCtrl = TextEditingController(); // override gross
  final _deductCtrl = TextEditingController();
  String _date = '';
  String _farmId = '';
  String _mandiId = '';
  String _cropId = '';
  String _payMode = 'Cash';

  final List<_BdRow> _rows = [];

  // ── computed ──
  double get _grossFromRows =>
      _rows.fold(0.0, (sum, r) => sum + r.sub);

  double get _grossAmount {
    final override = double.tryParse(_overrideCtrl.text);
    return (override != null && override > 0) ? override : _grossFromRows;
  }

  double get _deduction => double.tryParse(_deductCtrl.text) ?? 0;
  double get _netAmount => _grossAmount - _deduction;

  // ── total qty from breakdown ──
  double get _totalQty =>
      _rows.fold(0.0, (sum, r) => sum + (double.tryParse(r.qty.text) ?? 0));

  @override
  void initState() {
    super.initState();
    final data = widget.outerRef.read(appDataProvider);
    final e = widget.existing;
    if (e != null) {
      _buyerCtrl.text = e.buyer;
      _deductCtrl.text = e.deduction > 0 ? e.deduction.toStringAsFixed(0) : '';
      _date = e.date;
      _farmId = e.farmId;
      _mandiId = e.mandiId;
      _cropId = e.cropId;
      _payMode = e.payMode;
      // Restore breakdown rows
      if (e.breakdown.isNotEmpty) {
        for (final b in e.breakdown) {
          final row = _BdRow();
          row.qty.text = b.qty.toString();
          row.rate.text = b.rate.toString();
          _rows.add(row);
        }
        // If amount doesn't match computed, put it in override
        final computed = e.breakdown.fold<double>(0, (s, b) => s + b.sub);
        if ((computed - e.amount).abs() > 1) {
          _overrideCtrl.text = e.amount.toStringAsFixed(0);
        }
      } else {
        // Legacy: single row from qty+rate, or override
        if (e.rate > 0) {
          final row = _BdRow();
          row.qty.text = e.qty.toStringAsFixed(0);
          row.rate.text = e.rate.toStringAsFixed(2);
          _rows.add(row);
        } else {
          _overrideCtrl.text = e.amount.toStringAsFixed(0);
          _rows.add(_BdRow());
        }
      }
    } else {
      _date = DateTime.now().toIso8601String().substring(0, 10);
      _farmId = data.farms.isNotEmpty ? data.farms.first.id : '';
      _rows.add(_BdRow()); // start with one empty row
    }
  }

  @override
  void dispose() {
    _buyerCtrl.dispose();
    _overrideCtrl.dispose();
    _deductCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_BdRow()));

  void _removeRow(int i) {
    _rows[i].dispose();
    setState(() => _rows.removeAt(i));
  }

  void _save() {
    if (_buyerCtrl.text.trim().isEmpty) return;
    final notifier = widget.outerRef.read(appDataProvider.notifier);
    final breakdown = _rows
        .where((r) =>
            (double.tryParse(r.qty.text) ?? 0) > 0 ||
            (double.tryParse(r.rate.text) ?? 0) > 0)
        .map((r) => BreakdownItem(
              qty: (double.tryParse(r.qty.text) ?? 0).toInt(),
              rate: double.tryParse(r.rate.text) ?? 0,
              sub: r.sub,
            ))
        .toList();

    final sale = Sale(
      id: widget.existing?.id ?? notifier.newId('s'),
      date: _date,
      buyer: _buyerCtrl.text.trim(),
      qty: _totalQty,
      rate: breakdown.length == 1 ? breakdown.first.rate : 0,
      amount: _netAmount,
      deduction: _deduction,
      farmId: _farmId,
      mandiId: _mandiId,
      cropId: _cropId,
      payMode: _payMode,
      breakdown: breakdown,
    );
    if (widget.existing != null) notifier.updateSale(sale);
    else notifier.addSale(sale);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final farmMandis = data.mandis;           // all mandis (global)
    final farmCrops = _farmId.isEmpty
        ? data.crops
        : data.crops.where((c) => c.farmId == _farmId).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: AppColors.surface,
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(children: [
                Text(
                  widget.existing != null ? 'Edit Sale Record' : 'Add Sale Record',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            // ── Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Date + Buyer
                    _TwoCol(
                      left: _FieldBlock(
                        label: 'DATE',
                        child: _dateField(),
                      ),
                      right: _FieldBlock(
                        label: 'BUYER NAME',
                        child: _textField(_buyerCtrl, 'e.g. Prakashbhai-91'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Farm + Market
                    _TwoCol(
                      left: _FieldBlock(
                        label: 'FARM',
                        child: _drop(
                          value: _farmId.isEmpty ? null : _farmId,
                          hint: '— Select farm —',
                          items: data.farms
                              .map((f) => DropdownMenuItem(
                                  value: f.id, child: Text(f.name)))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _farmId = v ?? '';
                            _mandiId = '';
                            _cropId = '';
                          }),
                        ),
                      ),
                      right: _FieldBlock(
                        label: 'MARKET',
                        child: _drop(
                          value: _mandiId.isEmpty ? null : _mandiId,
                          hint: '— None —',
                          items: farmMandis
                              .map((m) => DropdownMenuItem(
                                  value: m.id, child: Text(m.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _mandiId = v ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Row 3: Crop + Payment Mode
                    _TwoCol(
                      left: _FieldBlock(
                        label: 'CROP',
                        child: _drop(
                          value: _cropId.isEmpty ? null : _cropId,
                          hint: '— None —',
                          items: farmCrops
                              .map((c) => DropdownMenuItem(
                                  value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _cropId = v ?? ''),
                        ),
                      ),
                      right: _FieldBlock(
                        label: 'PAYMENT MODE',
                        child: _drop(
                          value: _payMode,
                          hint: 'Cash',
                          items: ['Cash', 'Online', 'Other']
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _payMode = v ?? 'Cash'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── Stock Breakdown header
                    Row(children: [
                      const Text('STOCK BREAKDOWN (QTY × RATE)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.05)),
                      const Spacer(),
                      _AddRowBtn(onTap: _addRow),
                    ]),
                    const SizedBox(height: 8),
                    // ── Breakdown rows
                    ..._rows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final row = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BreakdownRow(
                          row: row,
                          onRemove: _rows.length > 1
                              ? () => _removeRow(i)
                              : null,
                          onChanged: () => setState(() {}),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    // ── Gross Amount display
                    _AmountBand(
                      label: 'Gross Amount',
                      amount: _grossAmount,
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    // Row 4: Override Gross + Deduction
                    _TwoCol(
                      left: _FieldBlock(
                        label: 'OVERRIDE GROSS (OPTIONAL)',
                        child: _textField(
                            _overrideCtrl, 'Leave blank',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {})),
                      ),
                      right: _FieldBlock(
                        label: 'DEDUCTION (₹)',
                        child: _textField(
                            _deductCtrl, '0',
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {})),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Net Amount Received
                    _AmountBand(
                      label: 'Net Amount Received',
                      amount: _netAmount,
                      isBold: true,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // ── Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.greenMid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Sora'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date field (shows date string, no picker required for parity with HTML)
  Widget _dateField() {
    final ctrl = TextEditingController(text: _date);
    ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
    return TextField(
      controller: ctrl,
      style: _kInputStyle,
      decoration: _kDec('YYYY-MM-DD'),
      onChanged: (v) => _date = v,
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: _kInputStyle,
        decoration: _kDec(hint),
        onChanged: onChanged,
      );

  Widget _drop({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) =>
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border2, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint, style: _kHintStyle),
            items: items,
            onChanged: onChanged,
            dropdownColor: AppColors.surface,
            isExpanded: true,
            isDense: true,
            style: _kInputStyle,
          ),
        ),
      );
}

// ── BREAKDOWN ROW WIDGET ──────────────────────────────────────────────────────
class _BreakdownRow extends StatelessWidget {
  final _BdRow row;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _BreakdownRow(
      {required this.row, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sub = row.sub;
    final subLabel = sub > 0
        ? '= ₹${sub.toStringAsFixed(0)}'
        : '= —';

    return Row(children: [
      // Qty
      Expanded(
        flex: 5,
        child: TextField(
          controller: row.qty,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Qty (kg)'),
          onChanged: (_) => onChanged(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('×',
            style: TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500)),
      ),
      // Rate
      Expanded(
        flex: 5,
        child: TextField(
          controller: row.rate,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Rate (₹)'),
          onChanged: (_) => onChanged(),
        ),
      ),
      // Sub-total label
      SizedBox(
        width: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(subLabel,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Sora')),
        ),
      ),
      // Remove button
      GestureDetector(
        onTap: onRemove,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: onRemove != null
                ? AppColors.redPale
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: onRemove != null
                  ? AppColors.red.withOpacity(0.25)
                  : AppColors.border,
            ),
          ),
          child: Icon(Icons.close,
              size: 14,
              color: onRemove != null
                  ? AppColors.red
                  : AppColors.textTertiary),
        ),
      ),
    ]);
  }
}

// ── AMOUNT BAND ───────────────────────────────────────────────────────────────
class _AmountBand extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _AmountBand(
      {required this.label, required this.amount, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.greenPale,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.greenMuted.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.greenMid)),
        const Spacer(),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.greenMid,
              fontFamily: 'Sora'),
        ),
      ]),
    );
  }
}

// ── + ADD ROW BUTTON ──────────────────────────────────────────────────────────
class _AddRowBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRowBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.greenPale,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.greenMuted.withOpacity(0.4)),
        ),
        child: const Text('+ Add Row',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.greenMid,
                fontFamily: 'Sora')),
      ),
    );
  }
}

// ── TWO-COL LAYOUT ────────────────────────────────────────────────────────────
class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TwoCol({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

// ── FIELD BLOCK ────────────────────────────────────────────────────────────────
class _FieldBlock extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.04)),
          const SizedBox(height: 5),
          child,
        ]);
  }
}

// ── MANDI FORM (quick add from dashboard / farms screen) ──────────────────────
Future<void> showMandiFormDialog(BuildContext context, WidgetRef ref,
    [String? defaultFarmId]) async {
  final data = ref.read(appDataProvider);
  if (data.farms.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a farm first')));
    return;
  }

  final nameCtrl = TextEditingController();
  final locCtrl = TextEditingController();
  String farmId = defaultFarmId ?? data.farms.first.id;

  await showDialog(
    context: context,
    builder: (ctx) =>
        StatefulBuilder(builder: (ctx, setState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          backgroundColor: AppColors.surface,
          child: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add Market',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 18),
                      _FieldBlock(
                          label: 'MARKET NAME',
                          child: TextField(
                              controller: nameCtrl,
                              style: _kInputStyle,
                              decoration:
                                  _kDec('Enter market name'))),
                      const SizedBox(height: 12),
                      _FieldBlock(
                          label: 'LOCATION',
                          child: TextField(
                              controller: locCtrl,
                              style: _kInputStyle,
                              decoration:
                                  _kDec('Enter location (optional)'))),
                      const SizedBox(height: 20),
                    ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: AppColors.border))),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.greenMid,
                            foregroundColor: Colors.white),
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          ref
                              .read(appDataProvider.notifier)
                              .addMandi(Mandi(
                                id: ref
                                    .read(appDataProvider.notifier)
                                    .newId('m'),
                                farmId: farmId,
                                name: nameCtrl.text.trim(),
                                location: locCtrl.text.trim(),
                              ));
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
                    ]),
              ),
            ]),
          ),
        )),
  );
}

// ── SHARED STYLE HELPERS ──────────────────────────────────────────────────────
const _kInputStyle =
    TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');
const _kHintStyle =
    TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora');

InputDecoration _kDec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _kHintStyle,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: AppColors.greenLight, width: 1.5)),
      filled: true,
      fillColor: AppColors.surface2,
    );
