import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
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

// ── BREAKDOWN ROW ─────────────────────────────────────────────────────────────
class _BdRow {
  final TextEditingController qty     = TextEditingController();
  final TextEditingController rate    = TextEditingController();
  final TextEditingController quality = TextEditingController();
  double get sub {
    final q = double.tryParse(qty.text)  ?? 0;
    final r = double.tryParse(rate.text) ?? 0;
    return q * r;
  }
  void dispose() { qty.dispose(); rate.dispose(); quality.dispose(); }
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
  // Controllers
  final _buyerCtrl      = TextEditingController();
  final _deductCtrl     = TextEditingController();
  final _deductDescCtrl = TextEditingController();

  // State
  String _date    = '';
  String _farmId  = '';
  String _mandiId = '';
  String _cropId  = '';
  String _payMode = 'Cash';
  String? _validationError;

  final List<_BdRow> _rows = [];

  // ── Computed ──────────────────────────────────────────────────────────────
  double get _grossFromRows => _rows.fold(0.0, (s, r) => s + r.sub);
  double get _grossAmount  => _grossFromRows;
  double get _deduction  => double.tryParse(_deductCtrl.text) ?? 0;
  double get _netAmount  => _grossAmount - _deduction;
  double get _totalQty   => _rows.fold(0.0, (s, r) => s + (double.tryParse(r.qty.text) ?? 0));

  // ── Buyer suggestions ─────────────────────────────────────────────────────
  List<String> get _buyerSuggestions {
    final all = widget.outerRef.read(appDataProvider).sales
        .map((s) => s.buyer)
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final q = _buyerCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return all.take(8).toList();
    return all.where((b) => b.toLowerCase().contains(q)).take(8).toList();
  }

  @override
  void initState() {
    super.initState();
    final data = widget.outerRef.read(appDataProvider);
    final e = widget.existing;
    if (e != null) {
      _buyerCtrl.text = e.buyer;
      _deductCtrl.text = e.deduction > 0 ? e.deduction.toStringAsFixed(0) : '';
      _deductDescCtrl.text = e.deductDesc;
      _date = e.date; _farmId = e.farmId; _mandiId = e.mandiId;
      _cropId = e.cropId; _payMode = e.payMode;
      if (e.breakdown.isNotEmpty) {
        for (final b in e.breakdown) {
          final r = _BdRow();
          r.qty.text     = b.qty.toString();
          r.rate.text    = b.rate.toString();
          r.quality.text = b.quality;
          _rows.add(r);
        }
      } else {
        if (e.rate > 0) {
          final r = _BdRow();
          r.qty.text  = e.qty.toStringAsFixed(0);
          r.rate.text = e.rate.toStringAsFixed(0);
          _rows.add(r);
        } else {
          _rows.add(_BdRow());
        }
      }
    } else {
      _date   = DateTime.now().toIso8601String().substring(0, 10);
      _farmId = data.farms.isNotEmpty ? data.farms.first.id : '';
      _rows.add(_BdRow());
    }
  }

  @override
  void dispose() {
    _buyerCtrl.dispose(); _deductCtrl.dispose(); _deductDescCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_BdRow()));
  void _removeRow(int i) { _rows[i].dispose(); setState(() => _rows.removeAt(i)); }

  // ── Validation & Save ─────────────────────────────────────────────────────
  void _save() {
    final buyer = _buyerCtrl.text.trim();
    if (buyer.isEmpty) {
      setState(() => _validationError = 'Buyer name is required.');
      return;
    }
    if (_farmId.isEmpty) {
      setState(() => _validationError = 'Please select a farm.');
      return;
    }
    if (_date.isEmpty) {
      setState(() => _validationError = 'Date is required.');
      return;
    }
    if (_netAmount <= 0 && _grossAmount <= 0) {
      setState(() => _validationError = 'Enter Qty × Rate in Stock Breakdown.');
      return;
    }
    setState(() => _validationError = null);

    final notifier = widget.outerRef.read(appDataProvider);
    final breakdown = _rows
        .where((r) => (double.tryParse(r.qty.text) ?? 0) > 0 || (double.tryParse(r.rate.text) ?? 0) > 0)
        .map((r) => BreakdownItem(
        qty: (double.tryParse(r.qty.text) ?? 0).toInt(),
        rate: double.tryParse(r.rate.text) ?? 0,
        sub: r.sub,
        quality: r.quality.text.trim()))
        .toList();

    final sale = Sale(
      id:         widget.existing?.id ?? notifier.newId('s'),
      date:       _date,
      buyer:      buyer,
      qty:        _totalQty,
      rate:       breakdown.length == 1 ? breakdown.first.rate : 0,
      amount:     _netAmount,
      deduction:  _deduction,
      deductDesc: _deductDescCtrl.text.trim(),
      farmId:     _farmId,
      mandiId:    _mandiId,
      cropId:     _cropId,
      payMode:    _payMode,
      breakdown:  breakdown,
    );
    if (widget.existing != null) notifier.updateSale(sale);
    else notifier.addSale(sale);
    Navigator.pop(context);
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    DateTime initial;
    try { initial = DateTime.parse(_date); } catch (_) { initial = DateTime.now(); }
    final first = DateTime(2020);
    final last  = DateTime(2030, 12, 31);
    final safe  = initial.isBefore(first) ? first : initial.isAfter(last) ? last : initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: safe,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: AppColors.greenMid, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data       = ref.watch(appDataProvider);
    final farmMandis = data.mandis;
    final farmCrops  = _farmId.isEmpty
        ? data.crops
        : data.crops.where((c) => c.farmId == _farmId).toList();

    // Display date formatted nicely
    String displayDate = _date;
    try {
      displayDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(_date));
    } catch (_) {}

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: AppColors.surface,
      child: LayoutBuilder(builder: (context, constraints) {
        final sw = MediaQuery.of(context).size.width;
        final dw = sw.isMobile ? sw * 0.96 : sw.isTablet ? sw * 0.82 : 580.0;
        return SizedBox(width: dw,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(children: [
                Text(
                  widget.existing != null ? 'Edit Sale Record' : 'Add Sale Record',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, fontFamily: 'Sora'),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Row 1: Date picker + Buyer with autocomplete
                  _TwoCol(
                    left: _FieldBlock(label: 'DATE',
                      child: InkWell(
                        onTap: _pickDate,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: AppColors.border2, width: 1.5),
                          ),
                          child: Row(children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 15, color: AppColors.greenMid),
                            const SizedBox(width: 8),
                            Expanded(child: Text(displayDate,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora'))),
                            const Icon(Icons.expand_more, size: 16, color: AppColors.textTertiary),
                          ]),
                        ),
                      ),
                    ),
                    right: _FieldBlock(label: 'BUYER NAME',
                      child: _BuyerField(
                        controller: _buyerCtrl,
                        suggestions: _buyerSuggestions,
                        onChanged: (_) => setState(() => _validationError = null),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Farm + Market
                  _TwoCol(
                    left: _FieldBlock(label: 'FARM',
                      child: _drop(
                        value: _farmId.isEmpty ? null : _farmId,
                        hint: '— Select farm —',
                        items: data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                        onChanged: (v) => setState(() { _farmId = v ?? ''; _mandiId = ''; _cropId = ''; }),
                      ),
                    ),
                    right: _FieldBlock(label: 'MARKET',
                      child: _drop(
                        value: _mandiId.isEmpty ? null : _mandiId,
                        hint: '— None —',
                        items: farmMandis.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                        onChanged: (v) => setState(() => _mandiId = v ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Row 3: Crop + Payment
                  _TwoCol(
                    left: _FieldBlock(label: 'CROP',
                      child: _drop(
                        value: _cropId.isEmpty ? null : _cropId,
                        hint: '— None —',
                        items: farmCrops.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _cropId = v ?? ''),
                      ),
                    ),
                    right: _FieldBlock(label: 'PAYMENT MODE',
                      child: _drop(
                        value: _payMode,
                        hint: 'Cash',
                        items: ['Cash','Online','Bank','Agnadiyu'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setState(() => _payMode = v ?? 'Cash'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stock breakdown header
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    const Flexible(child: Text('STOCK BREAKDOWN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary, letterSpacing: 0.05, fontFamily: 'Sora'),
                        overflow: TextOverflow.ellipsis)),
                    const Spacer(),
                    _AddRowBtn(onTap: _addRow),
                  ]),
                  const SizedBox(height: 8),

                  // Breakdown rows
                  ..._rows.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BreakdownRow(
                      row: entry.value,
                      onRemove: _rows.length > 1 ? () => _removeRow(entry.key) : null,
                      onChanged: () => setState(() {}),
                    ),
                  )),
                  const SizedBox(height: 4),

                  // Gross amount band
                  _AmountBand(label: 'Gross Amount', amount: _grossAmount, isBold: true),
                  const SizedBox(height: 12),

                  // Deduction amount + description
                  _TwoCol(
                    left: _FieldBlock(label: 'DEDUCTION (₹)',
                        child: _numField(_deductCtrl, '0')),
                    right: _FieldBlock(label: 'DEDUCTION DESCRIPTION',
                        child: TextField(
                          controller: _deductDescCtrl,
                          style: _kInputStyle,
                          decoration: _kDec('e.g. Commission, Transport...'),
                          onChanged: (_) => setState(() {}),
                        )),
                  ),
                  const SizedBox(height: 10),

                  // Net amount band
                  _AmountBand(label: 'Net Amount Received', amount: _netAmount, isBold: true),
                  const SizedBox(height: 16),
                ]),
              ),
            ),

            // ── Validation error ──
            if (_validationError != null)
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.redPale,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.red.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 15, color: AppColors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_validationError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w500, fontFamily: 'Sora'))),
                ]),
              ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Sora')),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenMid,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Sora'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  Widget _numField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    keyboardType: TextInputType.number,
    style: _kInputStyle,
    decoration: _kDec(hint),
    onChanged: (_) => setState(() {}),
  );

  Widget _drop({required String? value, required String hint,
    required List<DropdownMenuItem<String>> items, required ValueChanged<String?> onChanged}) =>
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border2, width: 1.5),
        ),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: _kHintStyle),
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.surface,
          isExpanded: true,
          isDense: true,
          style: _kInputStyle.copyWith(fontWeight: FontWeight.w700),
        )),
      );
}

// ── BUYER AUTOCOMPLETE FIELD ──────────────────────────────────────────────────
class _BuyerField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  const _BuyerField({required this.controller, required this.suggestions, required this.onChanged});
  @override
  State<_BuyerField> createState() => _BuyerFieldState();
}

class _BuyerFieldState extends State<_BuyerField> {
  bool _showDropdown = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() { if (!_focus.hasFocus) setState(() => _showDropdown = false); });
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.suggestions.where((s) {
      final q = widget.controller.text.trim().toLowerCase();
      return q.isEmpty || s.toLowerCase().contains(q);
    }).take(8).toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: widget.controller,
        focusNode: _focus,
        style: _kInputStyle,
        decoration: _kDec('e.g. Prakashbhai-91').copyWith(
          suffixIcon: filtered.isNotEmpty
              ? const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textTertiary)
              : null,
        ),
        onChanged: (v) {
          widget.onChanged(v);
          setState(() => _showDropdown = v.isNotEmpty && filtered.isNotEmpty);
        },
        onTap: () => setState(() => _showDropdown = filtered.isNotEmpty),
      ),
      if (_showDropdown && filtered.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border2, width: 1.5),
            boxShadow: AppShadows.shadow,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: filtered.map((name) => InkWell(
              onTap: () {
                widget.controller.text = name;
                widget.onChanged(name);
                setState(() => _showDropdown = false);
                _focus.unfocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Text(name, style: _kInputStyle),
                ]),
              ),
            )).toList(),
          ),
        ),
    ]);
  }
}

// ── BREAKDOWN ROW WIDGET ──────────────────────────────────────────────────────
class _BreakdownRow extends StatelessWidget {
  final _BdRow row;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  const _BreakdownRow({required this.row, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final sub = row.sub;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(flex: 5, child: TextField(
          controller: row.qty,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Qty (kg)'),
          onChanged: (_) => onChanged(),
        )),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('×', style: TextStyle(fontSize: 16, color: AppColors.textTertiary, fontFamily: 'Sora')),
        ),
        Expanded(flex: 5, child: TextField(
          controller: row.rate,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Rate (₹)'),
          onChanged: (_) => onChanged(),
        )),
        Flexible(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(sub > 0 ? '=₹${sub.toStringAsFixed(0)}' : '—',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'Sora'),
              overflow: TextOverflow.ellipsis),
        )),
        GestureDetector(
          onTap: onRemove,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: onRemove != null ? AppColors.redPale : AppColors.surface2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: onRemove != null ? AppColors.red.withOpacity(0.25) : AppColors.border),
            ),
            child: Icon(Icons.close, size: 14,
                color: onRemove != null ? AppColors.red : AppColors.textTertiary),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: row.quality,
        style: _kInputStyle,
        decoration: _kDec('Quality (e.g. A Grade, Premium, Mixed...)'),
        onChanged: (_) => onChanged(),
      ),
    ]);
  }
}

// ── AMOUNT BAND ───────────────────────────────────────────────────────────────
class _AmountBand extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  const _AmountBand({required this.label, required this.amount, this.isBold = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.greenPale,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.greenMuted.withOpacity(0.3)),
    ),
    child: Row(children: [
      Text(label, style: TextStyle(
          fontSize: 13, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: AppColors.greenMid, fontFamily: 'Sora')),
      const Spacer(),
      Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.greenMid, fontFamily: 'Sora')),
    ]),
  );
}

// ── ADD ROW BUTTON ────────────────────────────────────────────────────────────
class _AddRowBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddRowBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greenPale,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greenMuted.withOpacity(0.4)),
      ),
      child: const Text('+ Add Row', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.greenMid, fontFamily: 'Sora')),
    ),
  );
}

// ── LAYOUT HELPERS ────────────────────────────────────────────────────────────
class _TwoCol extends StatelessWidget {
  final Widget left, right;
  const _TwoCol({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width.isMobile;
    if (isMobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        left, const SizedBox(height: 10), right,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)],
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldBlock({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 0.04, fontFamily: 'Sora')),
      const SizedBox(height: 5),
      child,
    ],
  );
}

// ── MANDI QUICK-ADD (used from dashboard/farms) ───────────────────────────────
Future<void> showMandiFormDialog(BuildContext context, WidgetRef ref,
    [String? defaultFarmId]) async {
  final data = ref.read(appDataProvider);
  if (data.farms.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a farm first')));
    return;
  }
  final nameCtrl = TextEditingController();
  final locCtrl  = TextEditingController();
  String farmId  = defaultFarmId ?? data.farms.first.id;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: AppColors.surface,
      child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Market', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Sora')),
            const SizedBox(height: 18),
            _FieldBlock(label: 'MARKET NAME',
                child: TextField(controller: nameCtrl, style: _kInputStyle, decoration: _kDec('Enter market name'))),
            const SizedBox(height: 12),
            _FieldBlock(label: 'LOCATION',
                child: TextField(controller: locCtrl, style: _kInputStyle, decoration: _kDec('Enter location (optional)'))),
            const SizedBox(height: 20),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Sora'))),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.greenMid, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final n = ref.read(appDataProvider);
                n.addMandi(Mandi(id: n.newId('m'), farmId: farmId,
                    name: nameCtrl.text.trim(), location: locCtrl.text.trim()));
                Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(fontFamily: 'Sora')),
            ),
          ]),
        ),
      ])),
    )),
  );
}

// ── SHARED STYLE HELPERS ──────────────────────────────────────────────────────
const _kInputStyle = TextStyle(fontSize: 13, color: AppColors.textPrimary, fontFamily: 'Sora');
const _kHintStyle  = TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'Sora');

InputDecoration _kDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: _kHintStyle,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.greenMid, width: 1.5)),
  filled: true,
  fillColor: AppColors.surface2,
);