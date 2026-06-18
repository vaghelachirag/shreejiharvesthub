import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
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

// ── ROW MODELS ────────────────────────────────────────────────────────────────
class _ExpRow {
  String cat;
  final TextEditingController desc   = TextEditingController();
  final TextEditingController amount = TextEditingController();
  _ExpRow(this.cat);
  double get amt => double.tryParse(amount.text) ?? 0;
  void dispose() { desc.dispose(); amount.dispose(); }
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
  String _date    = '';
  String _farmId  = '';
  String _mandiId = '';
  String _cropId  = '';
  String _payMode = 'Cash';
  String? _validationError;

  final List<_ExpRow> _expRows = [];

  double get _totalExpense  => _expRows.fold(0.0, (s, r) => s + r.amt);

  // ── Desc suggestions from existing expenses ───────────────────────────────
  List<String> _descSuggestions(String query) {
    final all = widget.outerRef.read(appDataProvider).expenses
        .map((e) => e.desc)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()..sort();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all.take(8).toList();
    return all.where((d) => d.toLowerCase().contains(q)).take(8).toList();
  }

  @override
  void initState() {
    super.initState();
    final data = widget.outerRef.read(appDataProvider);
    final defaultCat = data.categories.isNotEmpty ? data.categories.first : 'Labour';
    final e = widget.existing;
    if (e != null) {
      _date = e.date; _farmId = e.farmId; _mandiId = e.mandiId;
      _cropId = e.cropId; _payMode = e.payMode;
      final row = _ExpRow(e.cat);
      row.desc.text   = e.desc;
      row.amount.text = e.amount.toStringAsFixed(0);
      _expRows.add(row);
    } else {
      _date   = DateTime.now().toIso8601String().substring(0, 10);
      _farmId = data.farms.isNotEmpty ? data.farms.first.id : '';
      _expRows.add(_ExpRow(defaultCat));
    }
  }

  @override
  void dispose() {
    for (final r in _expRows) {
      r.dispose();
    }
    super.dispose();
  }

  String _defaultCat() {
    final data = widget.outerRef.read(appDataProvider);
    return data.categories.isNotEmpty ? data.categories.first : 'Labour';
  }

  void _addExpRow() => setState(() => _expRows.add(_ExpRow(_defaultCat())));
  void _removeExpRow(int i) { _expRows[i].dispose(); setState(() => _expRows.removeAt(i)); }

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
      lastDate:  last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: AppColors.greenMid, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
  }

  // ── Validation + Save ─────────────────────────────────────────────────────
  void _save() {
    if (_date.isEmpty) {
      setState(() => _validationError = 'Date is required.'); return;
    }
    if (_farmId.isEmpty) {
      setState(() => _validationError = 'Please select a farm.'); return;
    }
    final validRows = _expRows.where((r) => r.desc.text.trim().isNotEmpty || r.amt > 0).toList();
    if (validRows.isEmpty) {
      setState(() => _validationError = 'Add at least one expense row with a description or amount.'); return;
    }
    setState(() => _validationError = null);

    final notifier = widget.outerRef.read(appDataProvider);
    if (widget.existing != null) {
      final r = validRows.first;
      notifier.updateExpense(widget.existing!.copyWith(
        date: _date,
        desc: r.desc.text.trim().isEmpty ? r.cat : r.desc.text.trim(),
        cat: r.cat, amount: _totalExpense,
        farmId: _farmId, mandiId: _mandiId, cropId: _cropId, payMode: _payMode,
      ));
    } else {
      for (final r in validRows) {
        notifier.addExpense(Expense(
          id: notifier.newId('e'), date: _date,
          desc: r.desc.text.trim().isEmpty ? r.cat : r.desc.text.trim(),
          cat: r.cat, amount: r.amt,
          farmId: _farmId, mandiId: _mandiId, cropId: _cropId, payMode: _payMode,
        ));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final data      = ref.watch(appDataProvider);
    final farmCrops = _farmId.isEmpty
        ? data.crops
        : data.crops.where((c) => c.farmId == _farmId).toList();

    String displayDate = _date;
    try { displayDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(_date)); } catch (_) {}

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
                Text(widget.existing != null ? 'Edit Expense' : 'Add Expense',
                    style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Body ──
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Row 1: Date picker + Payment Mode
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
                          const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.greenMid),
                          const SizedBox(width: 8),
                          Expanded(child: Text(displayDate,
                              style: GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary))),
                          const Icon(Icons.expand_more, size: 16, color: AppColors.textTertiary),
                        ]),
                      ),
                    ),
                  ),
                  right: _FieldBlock(label: 'PAYMENT MODE',
                      child: _drop(value: _payMode, hint: 'Cash',
                          items: ['Cash','Online','Bank','Agnadiyu'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                          onChanged: (v) => setState(() => _payMode = v ?? 'Cash'))),
                ),
                const SizedBox(height: 12),

                // Row 2: Farm + Market
                _TwoCol(
                  left: _FieldBlock(label: 'FARM',
                      child: _drop(value: _farmId.isEmpty ? null : _farmId, hint: '— Select farm —',
                          items: data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                          onChanged: (v) => setState(() { _farmId = v ?? ''; _mandiId = ''; _cropId = ''; }))),
                  right: _FieldBlock(label: 'MARKET',
                      child: _drop(value: _mandiId.isEmpty ? null : _mandiId, hint: '— None —',
                          items: data.mandis.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                          onChanged: (v) => setState(() => _mandiId = v ?? ''))),
                ),
                const SizedBox(height: 12),

                // Row 3: Crop (full width)
                _FieldBlock(label: 'CROP',
                    child: _drop(value: _cropId.isEmpty ? null : _cropId, hint: '— None —',
                        items: farmCrops.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _cropId = v ?? ''),
                        expand: true)),
                const SizedBox(height: 16),

                // ── Expense Breakdown ──
                Row(children: [
                  const Flexible(child: Text('EXPENSE BREAKDOWN',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary, letterSpacing: 0.05, fontFamily: 'Sora'),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  _AddRowBtn(onTap: _addExpRow),
                ]),
                const SizedBox(height: 8),
                ..._expRows.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExpBreakdownRow(
                    row: entry.value,
                    categories: data.categories,
                    suggestions: _descSuggestions(entry.value.desc.text),
                    onRemove: _expRows.length > 1 ? () => _removeExpRow(entry.key) : null,
                    onChanged: () => setState(() {}),
                  ),
                )),
                const SizedBox(height: 4),
                _AmountBand(label: 'Total Expense Amount', amount: _totalExpense, color: AppColors.greenMid, bold: true),
                const SizedBox(height: 16),
              ]),
            )),

            // ── Validation error banner ──
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
                      style: GoogleFonts.sora(fontSize: 12, color: AppColors.red, fontWeight: FontWeight.w500))),
                ]),
              ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      textStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w500)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.greenMid, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      textStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700),
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

  Widget _drop({required String? value, required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged, bool expand = false}) =>
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.surface2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border2, width: 1.5)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value, hint: Text(hint, style: _kHintStyle),
          items: items, onChanged: onChanged,
          dropdownColor: AppColors.surface,
          isExpanded: true, isDense: true, style: _kInputStyle.copyWith(fontWeight: FontWeight.w700),
        )),
      );
}

// ── EXPENSE BREAKDOWN ROW — with description autocomplete ─────────────────────
class _ExpBreakdownRow extends StatefulWidget {
  final _ExpRow row;
  final List<String> categories;
  final List<String> suggestions;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;
  const _ExpBreakdownRow({required this.row, required this.categories,
    required this.suggestions, required this.onRemove, required this.onChanged});
  @override
  State<_ExpBreakdownRow> createState() => _ExpBreakdownRowState();
}

class _ExpBreakdownRowState extends State<_ExpBreakdownRow> {
  bool _showSugg = false;
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(() { if (!_focus.hasFocus) setState(() => _showSugg = false); });
  }
  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.suggestions.where((s) {
      final q = widget.row.desc.text.trim().toLowerCase();
      return q.isEmpty || s.toLowerCase().contains(q);
    }).take(6).toList();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        // Category dropdown
        Flexible(flex: 2, child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: AppColors.surface2,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border2, width: 1.5)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: widget.categories.contains(widget.row.cat) ? widget.row.cat : widget.categories.first,
            items: widget.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) { widget.row.cat = v ?? widget.row.cat; widget.onChanged(); },
            dropdownColor: AppColors.surface, isExpanded: true, isDense: true, style: _kInputStyle.copyWith(fontWeight: FontWeight.w700),
          )),
        )),
        const SizedBox(width: 8),
        // Amount field
        Flexible(flex: 3, child: TextField(
          controller: widget.row.desc,
          focusNode: _focus,
          style: _kInputStyle,
          decoration: _kDec('Expense description'),
          onChanged: (v) { widget.onChanged(); setState(() => _showSugg = v.isNotEmpty && filtered.isNotEmpty); },
          onTap: () => setState(() => _showSugg = filtered.isNotEmpty),
        )),
        const SizedBox(width: 8),
        // Amount
        SizedBox(width: 110, child: TextField(
          controller: widget.row.amount,
          keyboardType: TextInputType.number,
          style: _kInputStyle,
          decoration: _kDec('Amount (₹)'),
          onChanged: (_) => widget.onChanged(),
        )),
        const SizedBox(width: 6),
        _RemoveBtn(onTap: widget.onRemove),
      ]),
      // Suggestions dropdown
      if (_showSugg && filtered.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 160),
          margin: const EdgeInsets.only(top: 2, left: 138),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border2, width: 1.5),
            boxShadow: AppShadows.shadow,
          ),
          child: ListView(shrinkWrap: true, padding: EdgeInsets.zero,
            children: filtered.map((name) => InkWell(
              onTap: () {
                widget.row.desc.text = name;
                widget.onChanged();
                setState(() => _showSugg = false);
                _focus.unfocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(children: [
                  const Icon(Icons.history, size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 7),
                  Text(name, style: _kInputStyle),
                ]),
              ),
            )).toList(),
          ),
        ),
    ]);
  }
}

// ── AMOUNT BAND ───────────────────────────────────────────────────────────────
class _AmountBand extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool bold;
  const _AmountBand({required this.label, required this.amount, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color == AppColors.amber ? AppColors.amberPale : AppColors.greenPale,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Text(label, style: GoogleFonts.sora(fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
      const Spacer(),
      Text('₹${amount.toStringAsFixed(0)}',
          style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ── SHARED SMALL WIDGETS ──────────────────────────────────────────────────────
class _RemoveBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _RemoveBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.redPale : AppColors.surface2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: onTap != null ? AppColors.red.withOpacity(0.25) : AppColors.border),
      ),
      child: Icon(Icons.close, size: 14,
          color: onTap != null ? AppColors.red : AppColors.textTertiary),
    ),
  );
}

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
        color: AppColors.greenPale, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.greenMuted.withOpacity(0.4)),
      ),
      child: Text('+ Add Row', style: GoogleFonts.sora(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.greenMid)),
    ),
  );
}

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
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 0.04)),
      const SizedBox(height: 5),
      child,
    ],
  );
}

// ── SHARED STYLE HELPERS ──────────────────────────────────────────────────────
final _kInputStyle = GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary);
final _kHintStyle  = GoogleFonts.sora(fontSize: 13, color: AppColors.textTertiary);

InputDecoration _kDec(String hint) => InputDecoration(
  hintText: hint, hintStyle: _kHintStyle,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5)),
  filled: true, fillColor: AppColors.surface2,
);