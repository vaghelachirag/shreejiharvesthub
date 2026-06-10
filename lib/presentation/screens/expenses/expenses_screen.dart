import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'expense_form_dialog.dart';

const _kPageSize = 10;

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _State();
}

class _State extends ConsumerState<ExpensesScreen> {
  String _search = '', _catFilter = '', _farmFilter = '', _mandiFilter = '', _cropFilter = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(dateFilterProvider);
    final data   = ref.watch(appDataProvider);

    var allExp = data.filteredExpenses(filter.range, filter.activeDate,
        farmId: _farmFilter, mandiId: _mandiFilter, cropId: _cropFilter, cat: _catFilter);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      allExp = allExp.where((e) =>
      e.desc.toLowerCase().contains(q) || e.cat.toLowerCase().contains(q)).toList();
    }

    final totalPages = (allExp.length / _kPageSize).ceil().clamp(1, 99999);
    final safePage   = _page.clamp(0, totalPages - 1);
    final pageExp    = allExp.skip(safePage * _kPageSize).take(_kPageSize).toList();

    String farmName(String id)  => AppUtils.farmName(data.farms, id);
    String mandiName(String id) => AppUtils.mandiName(data.mandis, id);
    String cropName(String id)  => AppUtils.cropName(data.crops, id);

    final totalAmt   = allExp.fold<double>(0, (s, r) => s + r.amount);
    final farmMandis = _farmFilter.isEmpty
        ? data.mandis
        : data.mandis.where((m) => m.farmId == _farmFilter).toList();

    final cellStyle  = GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary);
    final totalStyle = GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    final amtStyle   = GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amber);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search...', onChanged: (v) => setState(() { _search = v; _page = 0; })),
          FilterDropdown(
            value: _catFilter.isEmpty ? '' : _catFilter,
            items: [
              const DropdownMenuItem(value: '', child: Text('All categories')),
              ...data.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => setState(() { _catFilter = v ?? ''; _page = 0; }),
          ),
          FilterDropdown(
            value: _farmFilter.isEmpty ? '' : _farmFilter,
            items: [
              const DropdownMenuItem(value: '', child: Text('All Farms')),
              ...data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
            ],
            onChanged: (v) => setState(() { _farmFilter = v ?? ''; _mandiFilter = ''; _page = 0; }),
          ),
          FilterDropdown(
            value: _mandiFilter.isEmpty ? '' : _mandiFilter,
            items: [
              const DropdownMenuItem(value: '', child: Text('All Markets')),
              ...farmMandis.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
            ],
            onChanged: (v) => setState(() { _mandiFilter = v ?? ''; _page = 0; }),
          ),
          FilterDropdown(
            value: _cropFilter.isEmpty ? '' : _cropFilter,
            items: [
              const DropdownMenuItem(value: '', child: Text('All Crops')),
              ...data.crops.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (v) => setState(() { _cropFilter = v ?? ''; _page = 0; }),
          ),
          AddButton(label: '＋ Add Expense', onTap: () => showExpenseFormDialog(context, ref)),
          InkWell(
            onTap: () => _showCategoryManager(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(8)),
              child: Text('⊕ Manage Categories',
                  style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          _PdfBtn(onTap: () => _exportPdf(context, allExp, farmName, mandiName, cropName)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: allExp.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.trending_down_rounded, size: 52, color: AppColors.textTertiary.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text('No expenses for this period',
                style: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondary)),
          ]))
              : Column(children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 46,
                        dataRowMaxHeight: 56,
                        columnSpacing: 16,
                        horizontalMargin: 8,
                        dividerThickness: 0.8,
                        headingRowColor: WidgetStateProperty.all(Colors.transparent),
                        columns: [
                          DataColumn(label: _TH('Date')),
                          DataColumn(label: _TH('Description')),
                          DataColumn(label: _TH('Category')),
                          DataColumn(label: _TH('Farm')),
                          DataColumn(label: _TH('Market')),
                          DataColumn(label: _TH('Crop')),
                          DataColumn(label: _TH('Payment')),
                          DataColumn(label: _TH('Amount (₹)'), numeric: true),
                          DataColumn(label: _TH('')),
                        ],
                        rows: pageExp.map((e) => DataRow(
                          color: WidgetStateProperty.resolveWith((st) =>
                          st.contains(WidgetState.hovered) ? AppColors.amberPale.withOpacity(0.4) : null),
                          cells: [
                            DataCell(Text(AppUtils.formatDate(e.date), style: cellStyle)),
                            DataCell(SizedBox(width: 160,
                                child: Text(e.desc,
                                    style: cellStyle.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis))),
                            DataCell(AppBadge(label: e.cat, variant: BadgeVariant.amber)),
                            DataCell(Text(farmName(e.farmId), style: cellStyle)),
                            DataCell(Text(mandiName(e.mandiId), style: cellStyle)),
                            DataCell(Text(cropName(e.cropId), style: cellStyle)),
                            DataCell(AppBadge(label: e.payMode,
                                variant: e.payMode == 'Cash'   ? BadgeVariant.green
                                    : e.payMode == 'Online' ? BadgeVariant.blue
                                    : BadgeVariant.grey)),
                            DataCell(Text(AppUtils.formatCurrency(e.amount),
                                style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: AppColors.amber))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              ActionIconButton(icon: Icons.edit_outlined,
                                  onTap: () => showExpenseFormDialog(context, ref, e)),
                              const SizedBox(width: 4),
                              ActionIconButton(icon: Icons.delete_outline, isDanger: true,
                                  onTap: () async {
                                    final ok = await showConfirmDialog(context,
                                        message: 'Delete this expense?');
                                    if (ok) data.deleteExpense(e.id);
                                  }),
                            ])),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.amberPale.withOpacity(0.7),
                border: Border(top: BorderSide(color: AppColors.amber.withOpacity(0.3))),
              ),
              child: Row(children: [
                Expanded(child: Text('TOTAL  (${allExp.length} entries)', style: totalStyle)),
                Text(AppUtils.formatCurrency(totalAmt), style: amtStyle.copyWith(fontSize: 15)),
                const SizedBox(width: 52),
              ]),
            ),
            if (totalPages > 1)
              _PaginationBar(
                current: safePage, total: totalPages, count: allExp.length,
                onPrev: safePage > 0 ? () => setState(() => _page = safePage - 1) : null,
                onNext: safePage < totalPages - 1 ? () => setState(() => _page = safePage + 1) : null,
                onPage: (p) => setState(() => _page = p),
              ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _exportPdf(
      BuildContext context,
      List<Expense> expenses,
      String Function(String) farmName,
      String Function(String) mandiName,
      String Function(String) cropName,
      ) async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const _PdfProgressDialog(title: 'Expense Report'));
    try {
      final bytes = await _buildExpensesPdf(
          expenses: expenses, farmName: farmName, mandiName: mandiName, cropName: cropName);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Printing.sharePdf(bytes: bytes,
          filename: 'expense_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.red));
    }
  }

  void _showCategoryManager(BuildContext context) {
    final newCatCtrl = TextEditingController();
    showDialog(context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        final cats = ref.watch(appDataProvider).categories;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(width: 380, padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Manage Categories',
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6,
                children: cats.map((cat) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.amberPale, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.amber.withOpacity(0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.amber)),
                    const SizedBox(width: 5),
                    GestureDetector(onTap: () => ref.read(categoriesProvider.notifier).remove(cat),
                        child: const Icon(Icons.close, size: 13, color: AppColors.amber)),
                  ]),
                )).toList(),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextField(
                  controller: newCatCtrl,
                  style: GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'New category name',
                    hintStyle: GoogleFonts.sora(fontSize: 13, color: AppColors.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: AppColors.amber, width: 1.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: AppColors.border2, width: 1.5)),
                    filled: true, fillColor: AppColors.surface2,
                  ),
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: Colors.white),
                  onPressed: () {
                    final name = newCatCtrl.text.trim();
                    if (name.isNotEmpty) { ref.read(categoriesProvider.notifier).add(name); newCatCtrl.clear(); }
                  },
                  child: const Text('Add'),
                ),
              ]),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight,
                  child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))),
            ]),
          ),
        );
      }),
    );
  }
}

Future<Uint8List> _buildExpensesPdf({
  required List<Expense> expenses,
  required String Function(String) farmName,
  required String Function(String) mandiName,
  required String Function(String) cropName,
}) async {
  final fontRegular = await PdfGoogleFonts.notoSansRegular();
  final fontBold    = await PdfGoogleFonts.notoSansBold();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold));

  const amber   = PdfColor.fromInt(0xFFD97706);
  const amberLt = PdfColor.fromInt(0xFFFFFBEB);
  const border  = PdfColor.fromInt(0xFFE5E7EB);
  const textPri = PdfColor.fromInt(0xFF111827);
  const textSec = PdfColor.fromInt(0xFF6B7280);

  final totalAmt    = expenses.fold<double>(0, (s, r) => s + r.amount);
  final Map<String, double> byCat = {};
  for (final e in expenses) byCat[e.cat] = (byCat[e.cat] ?? 0) + e.amount;
  final catSorted   = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final generatedOn = AppUtils.formatDate(DateTime.now().toIso8601String());

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    header: (ctx) => pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Shreeji Harvest Hub',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: amber)),
          pw.Text('Expense Report', style: const pw.TextStyle(fontSize: 11, color: textSec)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Generated: $generatedOn', style: const pw.TextStyle(fontSize: 10, color: textSec)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: textSec)),
        ]),
      ]),
      pw.SizedBox(height: 6),
      pw.Divider(color: border, thickness: 1),
      pw.SizedBox(height: 6),
    ]),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: pw.BoxDecoration(color: amberLt, borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: border, width: 0.5)),
        child: pw.Row(children: [
          _expStat('Total Expenses', AppUtils.formatCurrency(totalAmt), amber),
          pw.SizedBox(width: 32),
          _expStat('Entries', '${expenses.length}', textPri),
          pw.SizedBox(width: 32),
          ...catSorted.take(4).map((e) => pw.Padding(
            padding: const pw.EdgeInsets.only(right: 24),
            child: _expStat(e.key,
                AppUtils.formatCurrency(e.value) +
                    (totalAmt > 0 ? ' (${(e.value / totalAmt * 100).toStringAsFixed(0)}%)' : ''),
                textPri),
          )),
        ]),
      ),
      pw.SizedBox(height: 14),
      pw.Table(
        border: pw.TableBorder.all(color: border, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.4), 1: const pw.FlexColumnWidth(2.2),
          2: const pw.FlexColumnWidth(1.4), 3: const pw.FlexColumnWidth(1.6),
          4: const pw.FlexColumnWidth(1.5), 5: const pw.FlexColumnWidth(1.5),
          6: const pw.FlexColumnWidth(1.2), 7: const pw.FlexColumnWidth(1.5),
        },
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: amber), children: [
            _expTh('Date'), _expTh('Description'), _expTh('Category'),
            _expTh('Farm'), _expTh('Market'), _expTh('Crop'),
            _expTh('Payment'), _expTh('Amount (Rs)'),
          ]),
          ...expenses.asMap().entries.map((entry) {
            final i = entry.key; final e = entry.value;
            final bg = i.isOdd ? const PdfColor.fromInt(0xFFF9FAFB) : PdfColors.white;
            return pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
              _expTd(AppUtils.formatDate(e.date)),
              _expTd(e.desc, bold: true),
              _expTd(e.cat),
              _expTd(farmName(e.farmId)),
              _expTd(mandiName(e.mandiId)),
              _expTd(cropName(e.cropId)),
              _expTd(e.payMode),
              _expTdAmt(AppUtils.formatCurrency(e.amount), amber),
            ]);
          }),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('TOTAL: ${AppUtils.formatCurrency(totalAmt)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: amber)),
      ]),
    ],
  ));
  return doc.save();
}

const _expCellPad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);

pw.Widget _expStat(String label, String value, PdfColor color) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B7280))),
      pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
    ]);

pw.Widget _expTh(String text) => pw.Padding(padding: _expCellPad,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)));

pw.Widget _expTd(String text, {bool bold = false}) => pw.Padding(padding: _expCellPad,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: const PdfColor.fromInt(0xFF111827))));

pw.Widget _expTdAmt(String text, PdfColor color) => pw.Padding(padding: _expCellPad,
    child: pw.Align(alignment: pw.Alignment.centerRight,
        child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color))));

// ── PDF PROGRESS DIALOG ───────────────────────────────────────────────────────
class _PdfProgressDialog extends StatefulWidget {
  final String title;
  const _PdfProgressDialog({required this.title});
  @override
  State<_PdfProgressDialog> createState() => _PdfProgressDialogState();
}

class _PdfProgressDialogState extends State<_PdfProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _msgIndex = 0;
  static const _messages = ['Preparing report data…', 'Building tables…', 'Generating PDF…'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _anim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.85).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
    ]).animate(_ctrl);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 700),  () { if (mounted) setState(() => _msgIndex = 1); });
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) setState(() => _msgIndex = 2); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, elevation: 0,
      child: Container(
        width: 280, padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border), boxShadow: AppShadows.shadowLg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 48, height: 48,
              decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.blue, size: 24)),
          const SizedBox(height: 16),
          Text('Generating ${widget.title}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, fontFamily: 'Sora')),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(_messages[_msgIndex], key: ValueKey(_msgIndex),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Sora')),
          ),
          const SizedBox(height: 18),
          Container(
            height: 6,
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(3)),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => ClipRRect(borderRadius: BorderRadius.circular(3),
                  child: Align(alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(widthFactor: _anim.value,
                          child: Container(decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.blue, AppColors.amber]),
                              borderRadius: BorderRadius.circular(3)))))),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(animation: _anim,
              builder: (_, __) => Align(alignment: Alignment.centerRight,
                  child: Text('${(_anim.value * 100).toInt()}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary, fontFamily: 'Sora')))),
        ]),
      ),
    );
  }
}

// ── PAGINATION BAR ────────────────────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int current, total, count;
  final VoidCallback? onPrev, onNext;
  final ValueChanged<int> onPage;
  const _PaginationBar({required this.current, required this.total,
    required this.count, required this.onPage, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    final start = (current - 2).clamp(0, (total - 5).clamp(0, total));
    final end   = (start + 5).clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Text('$count entries  ·  Page ${current + 1} of $total',
            style: GoogleFonts.sora(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        _PBtn(label: '‹', enabled: onPrev != null, onTap: onPrev),
        const SizedBox(width: 4),
        ...List.generate(end - start, (i) {
          final p = start + i;
          return Padding(padding: const EdgeInsets.only(right: 4),
              child: _PBtn(label: '${p + 1}', active: p == current,
                  enabled: p != current, onTap: () => onPage(p)));
        }),
        const SizedBox(width: 4),
        _PBtn(label: '›', enabled: onNext != null, onTap: onNext),
      ]),
    );
  }
}

class _PBtn extends StatelessWidget {
  final String label;
  final bool enabled, active;
  final VoidCallback? onTap;
  const _PBtn({required this.label, this.enabled = true, this.active = false, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null, borderRadius: BorderRadius.circular(7),
    child: Container(
      constraints: const BoxConstraints(minWidth: 30), height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.amber : (enabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: active ? AppColors.amber : AppColors.border),
      ),
      child: Center(child: Text(label, style: GoogleFonts.sora(fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? Colors.white : (enabled ? AppColors.textSecondary : AppColors.textTertiary)))),
    ),
  );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.06));
}

class _PdfBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PdfBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
        SizedBox(width: 6),
        Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Colors.white, fontFamily: 'Sora')),
      ]),
    ),
  );
}