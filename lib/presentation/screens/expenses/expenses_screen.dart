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
    final filter  = ref.watch(dateFilterProvider);
    final data    = ref.watch(appDataProvider);

    // ── All filtered expenses ──
    var allExp = data.filteredExpenses(filter.range, filter.activeDate,
        farmId: _farmFilter, mandiId: _mandiFilter, cropId: _cropFilter, cat: _catFilter);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      allExp = allExp.where((e) =>
          e.desc.toLowerCase().contains(q) || e.cat.toLowerCase().contains(q)).toList();
    }

    // ── Pagination ──
    final totalPages = (allExp.length / _kPageSize).ceil().clamp(1, 99999);
    final safePage   = _page.clamp(0, totalPages - 1);
    final pageExp    = allExp.skip(safePage * _kPageSize).take(_kPageSize).toList();

    // ── Name helpers ──
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

        // ── Toolbar ──────────────────────────────────────────────────────────
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(
            hint: 'Search...',
            onChanged: (v) => setState(() { _search = v; _page = 0; }),
          ),
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
          // Manage Categories button
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
          // PDF button — wired to real export
          InkWell(
            onTap: () => _exportPdf(allExp, farmName, mandiName, cropName),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
              child: Text('⬇ PDF',
                  style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Table area ───────────────────────────────────────────────────────
        Expanded(
          child: allExp.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.trending_down_rounded, size: 52, color: AppColors.textTertiary.withOpacity(0.35)),
                  const SizedBox(height: 12),
                  Text('No expenses for this period',
                      style: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondary)),
                ]))
              : Column(children: [
                  // ── Scrollable page entries ──
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

                  // ── Fixed totals row ──────────────────────────────────────
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

                  // ── Pagination bar ────────────────────────────────────────
                  if (totalPages > 1)
                    _PaginationBar(
                      current: safePage,
                      total: totalPages,
                      count: allExp.length,
                      onPrev: safePage > 0 ? () => setState(() => _page = safePage - 1) : null,
                      onNext: safePage < totalPages - 1 ? () => setState(() => _page = safePage + 1) : null,
                      onPage: (p) => setState(() => _page = p),
                    ),
                ]),
        ),
      ]),
    );
  }

  // ── PDF Export ──────────────────────────────────────────────────────────────
  Future<void> _exportPdf(
    List<Expense> expenses,
    String Function(String) farmName,
    String Function(String) mandiName,
    String Function(String) cropName,
  ) async {
    final doc     = pw.Document();
    final totalAmt = expenses.fold<double>(0, (s, r) => s + r.amount);

    // Category breakdown for summary
    final Map<String, double> byCat = {};
    for (final e in expenses) byCat[e.cat] = (byCat[e.cat] ?? 0) + e.amount;
    final catSorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        // Header
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Shreeji Harvest Hub',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Expense Report',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ]),
          pw.Text('Generated: ${AppUtils.formatDate(DateTime.now().toIso8601String().substring(0, 10))}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        ]),
        pw.SizedBox(height: 12),
        // Summary band
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
              color: PdfColors.orange50, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _pdfStat('Total Expenses', AppUtils.formatCurrency(totalAmt), PdfColors.orange800),
            _pdfStat('Transactions', '${expenses.length}', PdfColors.black),
            ...catSorted.take(4).map((e) => _pdfStat(e.key, AppUtils.formatCurrency(e.value), PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(height: 14),
        // Table
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Description', 'Category', 'Farm', 'Market', 'Crop', 'Payment', 'Amount (₹)'],
          data: expenses.map((e) => [
            AppUtils.formatDate(e.date), e.desc, e.cat,
            farmName(e.farmId), mandiName(e.mandiId), cropName(e.cropId),
            e.payMode, AppUtils.formatCurrency(e.amount),
          ]).toList(),
          border: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {7: pw.Alignment.centerRight},
        ),
        pw.SizedBox(height: 8),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('TOTAL: ${AppUtils.formatCurrency(totalAmt)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ]),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
      ]);

  // ── Category Manager ────────────────────────────────────────────────────────
  void _showCategoryManager(BuildContext context) {
    final newCatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        final cats = ref.watch(appDataProvider).categories;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 380, padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Manage Categories',
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Wrap(spacing: 6, runSpacing: 6,
                children: cats.map((cat) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.amberPale,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.amber.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(cat, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.amber)),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () => ref.read(categoriesProvider.notifier).remove(cat),
                      child: const Icon(Icons.close, size: 13, color: AppColors.amber),
                    ),
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
                    if (name.isNotEmpty) {
                      ref.read(categoriesProvider.notifier).add(name);
                      newCatCtrl.clear();
                    }
                  },
                  child: const Text('Add'),
                ),
              ]),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight,
                  child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'))),
            ]),
          ),
        );
      }),
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
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(7),
    child: Container(
      constraints: const BoxConstraints(minWidth: 30),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.amber : (enabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: active ? AppColors.amber : AppColors.border),
      ),
      child: Center(child: Text(label, style: GoogleFonts.sora(
        fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? Colors.white : (enabled ? AppColors.textSecondary : AppColors.textTertiary),
      ))),
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
