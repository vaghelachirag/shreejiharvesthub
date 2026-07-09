import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'sale_form_dialog.dart';

const _kPageSize = 10;

class SalesScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const SalesScreen({super.key, this.scrollController});
  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _search = '';
  String _farmFilter = '';
  String _mandiFilter = '';
  String _cropFilter = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(dateFilterProvider);
    final data   = ref.watch(appDataProvider);

    var allSales = data.filteredSales(filter.range, filter.activeDate,
        farmId: _farmFilter, mandiId: _mandiFilter, cropId: _cropFilter);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      allSales = allSales.where((s) => s.buyer.toLowerCase().contains(q)).toList();
    }

    final totalPages = (allSales.length / _kPageSize).ceil().clamp(1, 99999);
    final safePage   = _page.clamp(0, totalPages - 1);
    final pageStart  = safePage * _kPageSize;
    final pageSales  = allSales.skip(pageStart).take(_kPageSize).toList();

    String farmName(String id)  => AppUtils.farmName(data.farms, id);
    String mandiName(String id) => AppUtils.mandiName(data.mandis, id);
    String cropName(String id)  => AppUtils.cropName(data.crops, id);

    final totalAmt = allSales.fold<double>(0, (s, r) => s + r.amount);
    final totalQty = allSales.fold<double>(0, (s, r) => s + r.qty);

    final farmMandis = _farmFilter.isEmpty
        ? data.mandis
        : data.mandis.where((m) => m.farmId == _farmFilter).toList();

    final cellStyle  = GoogleFonts.sora(fontSize: 13, color: AppColors.textPrimary);
    final totalStyle = GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
    final amtStyle   = GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.greenMid);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          _PdfBtn(onTap: () => _exportPdf(context, allSales, farmName, mandiName, cropName)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: allSales.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.attach_money_rounded, size: 52, color: AppColors.textTertiary.withOpacity(0.35)),
            const SizedBox(height: 12),
            Text('No sales for this period',
                style: GoogleFonts.sora(fontSize: 14, color: AppColors.textSecondary)),
          ]))
              : Column(children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final isMobile = MediaQuery.of(context).size.width.isMobile;
                if (isMobile) {
                  // ── Mobile: card list ──
                  return ListView.separated(
                    controller: widget.scrollController,
                    itemCount: pageSales.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = pageSales[i];
                      final quality = s.breakdown.isNotEmpty
                          ? s.breakdown.map((b) => b.quality).where((q) => q.isNotEmpty).join(', ')
                          : '';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(s.buyer.isNotEmpty ? s.buyer : '—',
                                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary))),
                            AppBadge(label: s.payMode,
                                variant: s.payMode == 'Cash'   ? BadgeVariant.green
                                    : s.payMode == 'Online' ? BadgeVariant.blue
                                    : s.payMode == 'Bank'   ? BadgeVariant.blue
                                    : BadgeVariant.amber),
                            const SizedBox(width: 8),
                            ActionIconButton(icon: Icons.edit_outlined,
                                onTap: () => showSaleFormDialog(context, ref, s)),
                            ActionIconButton(icon: Icons.delete_outline, isDanger: true,
                                onTap: () async {
                                  final ok = await showConfirmDialog(context,
                                      message: 'Delete this sale entry?');
                                  if (ok) data.deleteSale(s.id);
                                }),
                          ]),
                          const SizedBox(height: 6),
                          Wrap(spacing: 12, runSpacing: 4, children: [
                            _InfoChip(Icons.calendar_today_outlined, AppUtils.formatDate(s.date)),
                            if (farmName(s.farmId).isNotEmpty && farmName(s.farmId) != '—')
                              _InfoChip(Icons.agriculture_outlined, farmName(s.farmId)),
                            if (cropName(s.cropId).isNotEmpty && cropName(s.cropId) != '—')
                              _InfoChip(Icons.grass_outlined, cropName(s.cropId)),
                            if (mandiName(s.mandiId).isNotEmpty && mandiName(s.mandiId) != '—')
                              _InfoChip(Icons.storefront_outlined, mandiName(s.mandiId)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _StatBox('Qty', '${AppUtils.formatNumber(s.qty)} kg'),
                            const SizedBox(width: 8),
                            _StatBox('Rate', s.rate > 0 ? '₹${s.rate.toStringAsFixed(0)}' : 'Mixed'),
                            if (s.deduction > 0) ...[
                              const SizedBox(width: 8),
                              _StatBox('Deduction', '-${AppUtils.formatCurrency(s.deduction)}'),
                            ],
                          ]),
                          if (quality.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Quality: $quality',
                                style: GoogleFonts.sora(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                          if (s.deductDesc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Deduction note: ${s.deductDesc}',
                                style: GoogleFonts.sora(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerRight,
                              child: Text(AppUtils.formatCurrency(s.amount),
                                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800,
                                      color: AppColors.greenMid))),
                        ]),
                      );
                    },
                  );
                }
                // ── Desktop/tablet: DataTable ──
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      controller: widget.scrollController,
                      child: DataTable(
                        headingRowHeight: 38,
                        dataRowMinHeight: 46,
                        dataRowMaxHeight: double.infinity,
                        columnSpacing: 16,
                        horizontalMargin: 8,
                        dividerThickness: 0.8,
                        headingRowColor: WidgetStateProperty.all(Colors.transparent),
                        columns: [
                          DataColumn(label: _TH('Date')),
                          DataColumn(label: _TH('Farm')),
                          DataColumn(label: _TH('Crop')),
                          DataColumn(label: _TH('Market')),
                          DataColumn(label: _TH('Buyer')),
                          DataColumn(label: _TH('Qty (kg)'), numeric: true),
                          DataColumn(label: _TH('Quality')),
                          DataColumn(label: _TH('Rate ₹/kg'), numeric: true),
                          DataColumn(label: _TH('Deduction'), numeric: true),
                          DataColumn(label: _TH('Deduct Desc')),
                          DataColumn(label: _TH('Payment')),
                          DataColumn(label: _TH('Amount (₹)'), numeric: true),
                          DataColumn(label: _TH('')),
                        ],
                        rows: pageSales.map((s) => DataRow(
                          color: WidgetStateProperty.resolveWith((st) =>
                          st.contains(WidgetState.hovered) ? AppColors.greenPale : null),
                          cells: [
                            DataCell(Text(AppUtils.formatDate(s.date), style: cellStyle)),
                            DataCell(Text(farmName(s.farmId), style: cellStyle)),
                            DataCell(Text(cropName(s.cropId), style: cellStyle)),
                            DataCell(Text(mandiName(s.mandiId), style: cellStyle)),
                            DataCell(Text(s.buyer, style: cellStyle.copyWith(fontWeight: FontWeight.w600))),
                            DataCell(Text(AppUtils.formatNumber(s.qty), style: cellStyle)),
                            DataCell(
                              s.breakdown.isNotEmpty
                                  ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: s.breakdown.map((b) => Text(
                                  b.quality.isNotEmpty ? b.quality : '—',
                                  style: cellStyle.copyWith(fontSize: 11),
                                )).toList(),
                              )
                                  : Text('—', style: cellStyle),
                            ),
                            DataCell(
                              s.breakdown.isNotEmpty
                                  ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: s.breakdown.map((b) {
                                  final lineAmt = b.qty * b.rate;
                                  return Text(
                                    '${AppUtils.formatNumber(b.qty)}kg × ₹${b.rate.toStringAsFixed(0)} = ${AppUtils.formatCurrency(lineAmt)}',
                                    style: cellStyle.copyWith(fontSize: 11),
                                  );
                                }).toList(),
                              )
                                  : Text(
                                s.rate > 0
                                    ? '${AppUtils.formatNumber(s.qty)}kg × ₹${s.rate.toStringAsFixed(0)} = ${AppUtils.formatCurrency(s.qty * s.rate)}'
                                    : '—',
                                style: cellStyle,
                              ),
                            ),
                            DataCell(Text(s.deduction > 0 ? '-${AppUtils.formatCurrency(s.deduction)}' : '—', style: cellStyle)),
                            DataCell(Text(s.deductDesc.isNotEmpty ? s.deductDesc : '—', style: cellStyle)),
                            DataCell(AppBadge(
                              label: s.payMode,
                              variant: s.payMode == 'Cash'     ? BadgeVariant.green
                                  : s.payMode == 'Online'  ? BadgeVariant.blue
                                  : s.payMode == 'Bank'    ? BadgeVariant.blue
                                  : BadgeVariant.amber,   // Agnadiyu + Other
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.greenPale,
                border: Border(top: BorderSide(color: AppColors.greenMuted.withOpacity(0.4))),
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final isMobile = MediaQuery.of(context).size.width.isMobile;
                if (isMobile) {
                  return Row(children: [
                    Expanded(child: Text('TOTAL  (${allSales.length})',
                        style: totalStyle.copyWith(color: AppColors.greenMid))),
                    Text('${AppUtils.formatNumber(totalQty)} kg', style: totalStyle),
                    const SizedBox(width: 12),
                    Text(AppUtils.formatCurrency(totalAmt), style: amtStyle.copyWith(fontSize: 14)),
                  ]);
                }
                return Row(children: [
                  Expanded(child: Text('TOTAL  (${allSales.length} entries)',
                      style: totalStyle.copyWith(color: AppColors.greenMid))),
                  Text('${AppUtils.formatNumber(totalQty)} kg', style: totalStyle),
                  const SizedBox(width: 32),
                  Text(AppUtils.formatCurrency(totalAmt), style: amtStyle.copyWith(fontSize: 15)),
                  const SizedBox(width: 52),
                ]);
              }),
            ),
            if (totalPages > 1)
              _PaginationBar(
                current: safePage,
                total: totalPages,
                count: allSales.length,
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
      List<Sale> sales,
      String Function(String) farmName,
      String Function(String) mandiName,
      String Function(String) cropName,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PdfProgressDialog(title: 'Sales Report'),
    );
    try {
      final bytes = await _buildSalesPdf(
          sales: sales, farmName: farmName, mandiName: mandiName, cropName: cropName);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'sales_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.red),
      );
    }
  }
}

Future<Uint8List> _buildSalesPdf({
  required List<Sale> sales,
  required String Function(String) farmName,
  required String Function(String) mandiName,
  required String Function(String) cropName,
}) async {
  final fontRegular = await PdfGoogleFonts.notoSansRegular();
  final fontBold    = await PdfGoogleFonts.notoSansBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
  );

  const green   = PdfColor.fromInt(0xFF16A34A);
  const greenLt = PdfColor.fromInt(0xFFF0FDF4);
  const border  = PdfColor.fromInt(0xFFE5E7EB);
  const textPri = PdfColor.fromInt(0xFF111827);
  const textSec = PdfColor.fromInt(0xFF6B7280);

  final totalAmt    = sales.fold<double>(0, (s, r) => s + r.amount);
  final totalQty    = sales.fold<double>(0, (s, r) => s + r.qty);
  final generatedOn = AppUtils.formatDate(DateTime.now().toIso8601String());

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    header: (ctx) => pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Shreeji Harvest Hub',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: green)),
          pw.Text('Sales Report', style: const pw.TextStyle(fontSize: 11, color: textSec)),
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
        decoration: pw.BoxDecoration(color: greenLt, borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: border, width: 0.5)),
        child: pw.Row(children: [
          _pdfStat('Total Sales',  AppUtils.formatCurrency(totalAmt), green),
          pw.SizedBox(width: 32),
          _pdfStat('Total Qty',    '${AppUtils.formatNumber(totalQty)} kg', textPri),
          pw.SizedBox(width: 32),
          _pdfStat('Transactions', '${sales.length}', textPri),
        ]),
      ),
      pw.SizedBox(height: 14),
      pw.Table(
        border: pw.TableBorder.all(color: border, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(1.3),  // Date
          1: const pw.FlexColumnWidth(1.4),  // Farm
          2: const pw.FlexColumnWidth(1.3),  // Crop
          3: const pw.FlexColumnWidth(1.4),  // Market
          4: const pw.FlexColumnWidth(1.6),  // Buyer
          5: const pw.FlexColumnWidth(1.0),  // Qty
          6: const pw.FlexColumnWidth(1.4),  // Quality
          7: const pw.FlexColumnWidth(2.2),  // Rate
          8: const pw.FlexColumnWidth(1.1),  // Deduction
          9: const pw.FlexColumnWidth(1.5),  // Deduct Desc
          10: const pw.FlexColumnWidth(1.0), // Payment
          11: const pw.FlexColumnWidth(1.4), // Amount
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: green),
            children: [
              _th('Date', PdfColors.white),    _th('Farm', PdfColors.white),
              _th('Crop', PdfColors.white),    _th('Market', PdfColors.white),
              _th('Buyer', PdfColors.white),   _th('Qty (kg)', PdfColors.white),
              _th('Quality', PdfColors.white), _th('Rate/kg', PdfColors.white),
              _th('Deduction', PdfColors.white), _th('Deduct Desc', PdfColors.white),
              _th('Payment', PdfColors.white),  _th('Amount (Rs)', PdfColors.white),
            ],
          ),
          ...sales.asMap().entries.map((entry) {
            final i = entry.key; final s = entry.value;
            final bg = i.isOdd ? const PdfColor.fromInt(0xFFF9FAFB) : PdfColors.white;
            return pw.TableRow(decoration: pw.BoxDecoration(color: bg), children: [
              _td(AppUtils.formatDate(s.date)),
              _td(farmName(s.farmId)),
              _td(cropName(s.cropId)),
              _td(mandiName(s.mandiId)),
              _td(s.buyer, bold: true),
              _tdRight(AppUtils.formatNumber(s.qty)),
              _td(s.breakdown.isNotEmpty
                  ? s.breakdown.map((b) => b.quality).where((q) => q.isNotEmpty).join(', ')
                  : '-'),
              s.breakdown.length > 1
                  ? pw.Padding(
                padding: _cellPad,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: s.breakdown.map((b) {
                    final lineAmt = b.qty * b.rate;
                    return pw.Text(
                      '${AppUtils.formatNumber(b.qty)}kg × ₹${b.rate.toStringAsFixed(0)} = ${AppUtils.formatCurrency(lineAmt)}',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF111827)),
                    );
                  }).toList(),
                ),
              )
                  : _tdRight(s.rate > 0 ? '₹${s.rate.toStringAsFixed(0)}' : '—'),
              _tdRight(s.deduction > 0 ? '-${AppUtils.formatCurrency(s.deduction)}' : '-'),
              _td(s.deductDesc.isNotEmpty ? s.deductDesc : '-'),
              _td(s.payMode),
              _tdColor(AppUtils.formatCurrency(s.amount), green),
            ]);
          }),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
        pw.Text('TOTAL: ${AppUtils.formatCurrency(totalAmt)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: green)),
      ]),
    ],
  ));
  return doc.save();
}

const _cellPad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);

pw.Widget _pdfStat(String label, String value, PdfColor color) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF6B7280))),
      pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
    ]);

pw.Widget _th(String text, PdfColor color) => pw.Padding(padding: _cellPad,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)));

pw.Widget _td(String text, {bool bold = false}) => pw.Padding(padding: _cellPad,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: const PdfColor.fromInt(0xFF111827))));

pw.Widget _tdRight(String text) => pw.Padding(padding: _cellPad,
    child: pw.Align(alignment: pw.Alignment.centerRight,
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF111827)))));

pw.Widget _tdColor(String text, PdfColor color) => pw.Padding(padding: _cellPad,
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)));

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
                              gradient: const LinearGradient(colors: [AppColors.blue, AppColors.greenMid]),
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
    final isMobile = MediaQuery.of(context).size.width.isMobile;
    final start = (current - 2).clamp(0, (total - 5).clamp(0, total));
    final end   = (start + 5).clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: isMobile
      // ── Mobile: compact prev / page X of Y / next ──
          ? Row(children: [
        _PBtn(label: '‹', enabled: onPrev != null, onTap: onPrev),
        const SizedBox(width: 8),
        Expanded(child: Text(
          '$count entries  ·  ${current + 1} / $total',
          style: GoogleFonts.sora(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        )),
        const SizedBox(width: 8),
        _PBtn(label: '›', enabled: onNext != null, onTap: onNext),
      ])
      // ── Desktop: full pagination with numbered buttons ──
          : Row(children: [
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
      constraints: const BoxConstraints(minWidth: 30), height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.greenMid : (enabled ? AppColors.surface2 : AppColors.surface2.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: active ? AppColors.greenMid : AppColors.border),
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
// ── MOBILE HELPER WIDGETS ─────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: AppColors.textTertiary),
    const SizedBox(width: 3),
    Text(label, style: GoogleFonts.sora(fontSize: 11, color: AppColors.textSecondary)),
  ]);
}

class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w700,
          color: AppColors.textTertiary, letterSpacing: 0.05)),
      const SizedBox(height: 1),
      Text(value, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary)),
    ]),
  );
}