import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';

Future<void> showExpenseFormDialog(
    BuildContext context, WidgetRef ref, [Expense? existing]) async {
  await showDialog(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => _ExpenseFormDialog(existing: existing, outerRef: ref),
  );
}

// ── EXPENSE BREAKDOWN ROW ─────────────────────────────────────────────────────
class _ExpRow {
  String cat;
  final TextEditingController desc;
  final TextEditingController amount;

  _ExpRow(String defaultCat)
      : cat = defaultCat,
        desc = TextEditingController(),
        amount = TextEditingController();

  double get amt => double.tryParse(amount.text) ?? 0;

  void dispose() {
    desc.dispose();
    amount.dispose();
  }
}

// ── DEDUCTION ROW ─────────────────────────────────────────────────────────────
class _DedRow {
  final TextEditingController desc;
  final TextEditingController amount;

  _DedRow()
      : desc = TextEditingController(),
        amount = TextEditingController();

  double get amt => double.tryParse(amount.text) ?? 0;

  void dispose() {
    desc.dispose();
    amount.dispose();
  }
}

// ── DIALOG ────────────────────────────────────────────────────────────────────
class _ExpenseFormDialog extends ConsumerStatefulWidget {
  final Expense? existing;
  final WidgetRef outerRef;
  const _ExpenseFormDialog({this.existing, required this.outerRef});

  @override
  ConsumerState<_ExpenseFormDialog> createState() => _State();
}

class _State extends ConsumerState<_ExpenseFormDialog> {
  String _date = '';
  String _farmId = '';
  String _mandiId = '';
  String _cropId = '';
  String _payMode = 'Cash';

  final List<_ExpRow> _expRows = [];
  final List<_DedRow> _dedRows = [];

  // ── computed ──
  double get _totalExpense =>
      _expRows.fold(0.0, (s, r) => s + r.amt);
  double get _totalDeduction =>
      _dedRows.fold(0.0, (s, r) => s + r.amt);
  double get _netExpense => _totalExpense - _totalDeduction;

  @override
  void initState() {
    super.initState();
    final data = widget.outerRef.read(appDataProvider);
    final defaultCat =
        data.categories.isNotEmpty ? data.categories.first : 'Labour';
    final e = widget.existing;

    if (e != null) {
      _date = e.date;
      _farmId = e.farmId;
      _mandiId = e.mandiId;
      _cropId = e.cropId;
      _payMode = e.payMode;
      // Restore single row from existing expense
      final row = _ExpRow(e.cat);
      row.desc.text = e.desc;
      row.amount.text = e.amount.toStringAsFixed(0);
      _expRows.add(row);
    } else {
      _date = DateTime.now().toIso8601String().substring(0, 10);
      _farmId = data.farms.isNotEmpty ? data.farms.first.id : '';
      _expRows.add(_ExpRow(defaultCat));
    }
    _dedRows.add(_DedRow()); // always start with one deduction row
  }

  @override
  void dispose() {
    for (final r in _expRows) r.dispose();
    for (final r in _dedRows) r.dispose();
    super.dispose();
  }

  String _defaultCat() {
    final data = widget.outerRef.read(appDataProvider);
    return data.categories.isNotEmpty ? data.categories.first : 'Labour';
  }

  void _addExpRow() =>
      setState(() => _expRows.add(_ExpRow(_defaultCat())));

  void _removeExpRow(int i) {
    _expRows[i].dispose();
    setState(() => _expRows.removeAt(i));
  }

  void _addDedRow() => setState(() => _dedRows.add(_DedRow()));

  void _removeDedRow(int i) {
    _dedRows[i].dispose();
    setState(() => _dedRows.removeAt(i));
  }

  void _save() {
    final notifier = widget.outerRef.read(appDataProvider.notifier);

    // If multiple expense rows, save each as a separate Expense entry
    final validRows = _expRows
        .where((r) => r.desc.text.trim().isNotEmpty || r.amt > 0)
        .toList();

    if (validRows.isEmpty) return;

    if (widget.existing != null) {
      // Update: collapse back to single entry (first valid row)
      final r = validRows.first;
      final updated = widget.existing!.copyWith(
        date: _date,
        desc: r.desc.text.trim().isEmpty ? r.cat : r.desc.text.trim(),
        cat: r.cat,
        amount: _netExpense,
        farmId: _farmId,
        mandiId: _mandiId,
        cropId: _cropId,
        payMode: _payMode,
      );
      notifier.updateExpense(updated);
    } else {
      // Add: each expense row becomes a separate entry
      for (final r in validRows) {
        final expense = Expense(
          id: notifier.newId('e'),
          date: _date,
          desc: r.desc.text.trim().isEmpty ? r.cat : r.desc.text.trim(),
          cat: r.cat,
          amount: r.amt,
          farmId: _farmId,
          mandiId: _mandiId,
          cropId: _cropId,
          payMode: _payMode,
        );
        notifier.addExpense(expense);
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
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
            // ── Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(children: [
                Text(
                  widget.existing != null
                      ? 'Edit Expense'
                      : 'Add Expense',
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
                    // Row 1: Date + Payment Mode
                    _TwoCol(
                      left: _FieldBlock(
                        label: 'DATE',
                        child: _dateField(),
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
                          items: data.mandis
                              .map((m) => DropdownMenuItem(
                                  value: m.id, child: Text(m.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _mandiId = v ?? ''),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Row 3: Crop (full width)
                    _FieldBlock(
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
                        expand: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── EXPENSE BREAKDOWN ──
                    Row(children: [
                      const Text('EXPENSE BREAKDOWN',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.05)),
                      const Spacer(),
                      _AddRowBtn(onTap: _addExpRow),
                    ]),
                    const SizedBox(height: 8),
                    ..._expRows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final row = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ExpBreakdownRow(
                          row: row,
                          categories: data.categories,
                          onRemove: _expRows.length > 1
                              ? () => _removeExpRow(i)
                              : null,
                          onChanged: () => setState(() {}),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    _AmountBand(
                      label: 'Total Expense Amount',
                      amount: _totalExpense,
                      color: AppColors.greenMid,
                    ),
                    const SizedBox(height: 16),

                    // ── DEDUCTION BREAKDOWN ──
                    Row(children: [
                      const Text('DEDUCTION BREAKDOWN',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.05)),
                      const Spacer(),
                      _AddRowBtn(onTap: _addDedRow),
                    ]),
                    const SizedBox(height: 8),
                    ..._dedRows.asMap().entries.map((entry) {
                      final i = entry.key;
                      final row = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DedBreakdownRow(
                          row: row,
                          onRemove: _dedRows.length > 1
                              ? () => _removeDedRow(i)
                              : null,
                          onChanged: () => setState(() {}),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    _AmountBand(
                      label: 'Total Deduction',
                      amount: _totalDeduction,
                      color: AppColors.amber,
                    ),
                    const SizedBox(height: 8),
                    _AmountBand(
                      label: 'Net Expense Amount',
                      amount: _netExpense,
                      color: AppColors.greenMid,
                      bold: true,
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
                  border: Border(
                      top: BorderSide(color: AppColors.border))),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenMid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
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

  Widget _dateField() {
    final ctrl = TextEditingController(text: _date);
    ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: ctrl.text.length));
    return TextField(
      controller: ctrl,
      style: _kInputStyle,
      decoration: _kDec('YYYY-MM-DD'),
      onChanged: (v) => _date = v,
    );
  }

  Widget _drop({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool expand = false,
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

// ── EXPENSE BREAKDOWN ROW ─────────────────────────────────────────────────────
class _ExpBreakdownRow extends StatelessWidget {
  final _ExpRow row;
  final List<String> categories;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _ExpBreakdownRow({
    required this.row,
    required this.categories,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Category dropdown
      SizedBox(
        width: 140,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border2, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: categories.contains(row.cat) ? row.cat : categories.first,
              items: categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                row.cat = v ?? row.cat;
                onChanged();
              },
              dropdownColor: AppColors.surface,
              isExpanded: true,
              isDense: true,
              style: _kInputStyle,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Description
      Expanded(
        child: TextField(
          controller: row.desc,
          style: _kInputStyle,
          decoration: _kDec('Expense description'),
          onChanged: (_) => onChanged(),
        ),
      ),
      const SizedBox(width: 8),
      // Amount
      SizedBox(
        width: 110,
        child: TextField(
          controller: row.amount,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Amount (₹)'),
          onChanged: (_) => onChanged(),
        ),
      ),
      const SizedBox(width: 6),
      // Remove
      _RemoveBtn(onTap: onRemove),
    ]);
  }
}

// ── DEDUCTION BREAKDOWN ROW ───────────────────────────────────────────────────
class _DedBreakdownRow extends StatelessWidget {
  final _DedRow row;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _DedBreakdownRow({
    required this.row,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Description (wider)
      Expanded(
        child: TextField(
          controller: row.desc,
          style: _kInputStyle,
          decoration: _kDec('Deduction description'),
          onChanged: (_) => onChanged(),
        ),
      ),
      const SizedBox(width: 8),
      // Amount
      SizedBox(
        width: 130,
        child: TextField(
          controller: row.amount,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Amount (₹)'),
          onChanged: (_) => onChanged(),
        ),
      ),
      const SizedBox(width: 6),
      // Remove
      _RemoveBtn(onTap: onRemove),
    ]);
  }
}

// ── AMOUNT BAND ───────────────────────────────────────────────────────────────
class _AmountBand extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool bold;

  const _AmountBand({
    required this.label,
    required this.amount,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDeduction = color == AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDeduction
            ? AppColors.amberPale
            : AppColors.greenPale,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isDeduction
              ? AppColors.amber.withOpacity(0.3)
              : AppColors.greenMuted.withOpacity(0.3),
        ),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w600,
                color: color)),
        const Spacer(),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Sora'),
        ),
      ]),
    );
  }
}

// ── REMOVE BUTTON ─────────────────────────────────────────────────────────────
class _RemoveBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _RemoveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.redPale
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: onTap != null
                ? AppColors.red.withOpacity(0.25)
                : AppColors.border,
          ),
        ),
        child: Icon(Icons.close,
            size: 14,
            color: onTap != null
                ? AppColors.red
                : AppColors.textTertiary),
      ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.greenPale,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.greenMuted.withOpacity(0.4)),
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
          borderSide:
              const BorderSide(color: AppColors.border2, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: AppColors.border2, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: AppColors.greenLight, width: 1.5)),
      filled: true,
      fillColor: AppColors.surface2,
    );
