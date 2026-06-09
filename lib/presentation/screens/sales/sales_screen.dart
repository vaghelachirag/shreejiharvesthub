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
import 'sale_form_dialog.dart';

// ── PAGE SIZE ─────────────────────────────────────────────────────────────────
const _kPageSize = 10;

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});
  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _search = '';
  String _farmFilter = '';
  String _mandiFilter = '';
  String _cropFilter = '';
  int _page = 0; // current page index (0-based)

  @override
  Widget build(BuildContext context) {
    final filter  = ref.watch(dateFilterProvider);
    final data    = ref.watch(appDataProvider);

    // ── All filtered sales (for totals + PDF) ──
    var allSales = data.filteredSales(filter.range, filter.activeDate,
        farmId: _farmFilter, mandiId: _mandiFilter, cropId: _cropFilter);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      allSales = allSales.where((s) => s.buyer.toLowerCase().contains(q)).toList();
    }

    // ── Pagination ──
    final totalPages = (allSales.length / _kPageSize).ceil().clamp(1, 99999);
    final safePage   = _page.clamp(0, totalPages - 1);
    final pageStart  = safePage * _kPageSize;
    // Page entries (max 10) — totals row uses allSales
    final pageSales  = allSales.skip(pageStart).take(_kPageSize).toList();

    // ── Name helpers ──
    String farmName(String id)  => AppUtils.farmName(data.farms, id);
    String mandiName(String id) => AppUtils.mandiName(data.mandis, id);
    String cropName(String id)  => AppUtils.cropName(data.crops, id);

    // ── Grand totals (over ALL filtered sales, not just current page) ──
    final totalAmt = allSales.fold<double>(0, (s, r) => s + r.amount);
    final totalQty = allSales.fold<double>(0, (s, r) => s + r.qty);

    final farmMandis = _farmFilter.isEmpty
        ? data.mandis
        : data.mandis.where((m) => m.farmId == _farmFilter).toList();

    // ── Text styles using Sora font ──
    final cellStyle = GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary);
    final totalStyle = GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    final amtStyle   = GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.greenMid);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Toolbar ──────────────────────────────────────────────────────────
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(
            hint: 'Search buyer...',
            onChanged: (v) => setState(() { _search = v; _page = 0; }),
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
          AddButton(label: '＋ Add Sale', onTap: () => showSaleFormDialog(context, ref)),
          _PdfBtn(onTap: () => _exportPdf(allSales, farmName, mandiName, cropName)),
        ]),
        const SizedBox(height: 12),

        // ── Table area — fills remaining space ───────────────────────────────
        Expanded(
          child: allSales.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.attach_money_rounded, size: 52, color: AppColors.textTertiary.withOpacity(0.35)),
                  const SizedBox(height: 12),
                  Text('No sales for this period',
                      style: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondary)),
                ]))
              : Column(children: [
                  // ── Scrollable entries (10 per page) ──
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
                                DataColumn(label: _TH('Buyer')),
                                DataColumn(label: _TH('Farm')),
                                DataColumn(label: _TH('Market')),
                                DataColumn(label: _TH('Crop')),
                                DataColumn(label: _TH('Qty (kg)'), numeric: true),
                                DataColumn(label: _TH('Rate ₹/kg'), numeric: true),
                                DataColumn(label: _TH('Deduction'), numeric: true),
                                DataColumn(label: _TH('Payment')),
                                DataColumn(label: _TH('Amount (₹)'), numeric: true),
                                DataColumn(label: _TH('')),
                              ],
                              rows: pageSales.map((s) => DataRow(
                                color: WidgetStateProperty.resolveWith((st) =>
                                    st.contains(WidgetState.hovered) ? AppColors.greenPale : null),
                                cells: [
                                  DataCell(Text(AppUtils.formatDate(s.date), style: cellStyle)),
                                  DataCell(Text(s.buyer, style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
                                  DataCell(Text(farmName(s.farmId), style: cellStyle)),
                                  DataCell(Text(mandiName(s.mandiId), style: cellStyle)),
                                  DataCell(Text(cropName(s.cropId), style: cellStyle)),
                                  DataCell(Text(AppUtils.formatNumber(s.qty), style: cellStyle)),
                                  DataCell(Text(s.rate > 0 ? '₹${s.rate.toStringAsFixed(0)}' : 'Mixed', style: cellStyle)),
                                  DataCell(Text(s.deduction > 0 ? '-${AppUtils.formatCurrency(s.deduction)}' : '—', style: cellStyle)),
                                  DataCell(AppBadge(
                                    label: s.payMode,
                                    variant: s.payMode == 'Cash'   ? BadgeVariant.green
                                           : s.payMode == 'Online' ? BadgeVariant.blue
                                           : BadgeVariant.amber,
                                  )),
                                  DataCell(Text(AppUtils.formatCurrency(s.amount),
                                      style: cellStyle.copyWith(fontWeight: FontWeight.w700, color: AppColors.greenMid))),
                                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                    ActionIconButton(
                                      icon: Icons.edit_outlined,
                                      onTap: () => showSaleFormDialog(context, ref, s),
                                    ),
                                    const SizedBox(width: 4),
                                    ActionIconButton(
                                      icon: Icons.delete_outline,
                                      isDanger: true,
                                      onTap: () async {
                                        final ok = await showConfirmDialog(context,
                                            message: 'Delete this sale entry?');
                                        if (ok) data.deleteSale(s.id);
                                      },
                                    ),
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
                      color: AppColors.greenPale,
                      border: Border(top: BorderSide(color: AppColors.greenMuted.withOpacity(0.4))),
                    ),
                    child: Row(children: [
                      Expanded(child: Text('TOTAL  (${allSales.length} entries)',
                          style: totalStyle.copyWith(color: AppColors.greenMid))),
                      Text('${AppUtils.formatNumber(totalQty)} kg',
                          style: totalStyle),
                      const SizedBox(width: 32),
                      Text(AppUtils.formatCurrency(totalAmt),
                          style: amtStyle.copyWith(fontSize: 15)),
                      const SizedBox(width: 52), // aligns with action column
                    ]),
                  ),

                  // ── Pagination bar ────────────────────────────────────────
                  if (totalPages > 1)
                    _PaginationBar(
                      current: safePage,
                      total: totalPages,
                      count: allSales.length,
                      onPrev: safePage > 0
                          ? () => setState(() => _page = safePage - 1)
                          : null,
                      onNext: safePage < totalPages - 1
                          ? () => setState(() => _page = safePage + 1)
                          : null,
                      onPage: (p) => setState(() => _page = p),
                    ),
                ]),
        ),
      ]),
    );
  }

  // ── PDF Export ──────────────────────────────────────────────────────────────
  Future<void> _exportPdf(
    List<Sale> sales,
    String Function(String) farmName,
    String Function(String) mandiName,
    String Function(String) cropName,
  ) async {
    final doc = pw.Document();
    final totalAmt = sales.fold<double>(0, (s, r) => s + r.amount);
    final totalQty = sales.fold<double>(0, (s, r) => s + r.qty);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        // ── Header
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Shreeji Harvest Hub',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Sales Report',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ]),
          pw.Text('Generated: ${AppUtils.formatDate(DateTime.now().toIso8601String().substring(0, 10))}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        ]),
        pw.SizedBox(height: 12),
        // ── Summary band
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _pdfStat('Total Sales', AppUtils.formatCurrency(totalAmt), PdfColors.green800),
            _pdfStat('Total Qty', '${AppUtils.formatNumber(totalQty)} kg', PdfColors.black),
            _pdfStat('Transactions', '${sales.length}', PdfColors.black),
          ]),
        ),
        pw.SizedBox(height: 14),
        // ── Table
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Buyer', 'Farm', 'Market', 'Crop', 'Qty (kg)', 'Rate ₹/kg', 'Deduction', 'Payment', 'Amount (₹)'],
          data: sales.map((s) => [
            AppUtils.formatDate(s.date),
            s.buyer,
            farmName(s.farmId),
            mandiName(s.mandiId),
            cropName(s.cropId),
            AppUtils.formatNumber(s.qty),
            s.rate > 0 ? '₹${s.rate.toStringAsFixed(0)}' : 'Mixed',
            s.deduction > 0 ? '-${AppUtils.formatCurrency(s.deduction)}' : '—',
            s.payMode,
            AppUtils.formatCurrency(s.amount),
          ]).toList(),
          border: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignments: {5: pw.Alignment.centerRight, 6: pw.Alignment.centerRight,
                           7: pw.Alignment.centerRight, 9: pw.Alignment.centerRight},
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

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
    ]);
  }
}

// ── PAGINATION BAR ────────────────────────────────────────────────────────────
class _PaginationBar extends StatelessWidget {
  final int current, total, count;
  final VoidCallback? onPrev, onNext;
  final ValueChanged<int> onPage;

  const _PaginationBar({
    required this.current, required this.total,
    required this.count, required this.onPage,
    this.onPrev, this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    // Show at most 5 page buttons centred around current
    final start = (current - 2).clamp(0, (total - 5).clamp(0, total));
    final end   = (start + 5).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Text('$count entries  ·  Page ${current + 1} of $total',
            style: GoogleFonts.sora(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        _PBtn(label: '‹', enabled: onPrev != null, onTap: onPrev),
        const SizedBox(width: 4),
        ...List.generate(end - start, (i) {
          final p = start + i;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _PBtn(
              label: '${p + 1}',
              active: p == current,
              enabled: p != current,
              onTap: () => onPage(p),
            ),
          );
        }),
        const SizedBox(width: 4),
        _PBtn(label: '›', enabled: onNext != null, onTap: onNext),
      ]),
    );
  }
}

class _PBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool active;
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
        color: active ? AppColors.greenMid : (enabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: active ? AppColors.greenMid : AppColors.border),
      ),
      child: Center(child: Text(label, style: GoogleFonts.sora(
        fontSize: 12,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
        color: active ? Colors.white : (enabled ? AppColors.textSecondary : AppColors.textTertiary),
      ))),
    ),
  );
}

// ── COLUMN HEADER ─────────────────────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 0.06));
}

// ── PDF BUTTON ────────────────────────────────────────────────────────────────
class _PdfBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _PdfBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
      child: Text('⬇ PDF',
          style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );
}
