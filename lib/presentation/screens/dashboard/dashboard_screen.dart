import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'main_shell.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const DashboardScreen({super.key, this.scrollController});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(dateFilterProvider);
    final dashFilter = ref.watch(dashboardFilterProvider);
    final data = ref.watch(appDataProvider);
    final notifier = ref.read(appDataProvider);

    final sales = notifier.filteredSales(filter.range, filter.activeDate,
        farmId: dashFilter.farmId,
        mandiId: dashFilter.mandiId,
        cropId: dashFilter.cropId);
    final expenses = notifier.filteredExpenses(filter.range, filter.activeDate,
        farmId: dashFilter.farmId,
        mandiId: dashFilter.mandiId,
        cropId: dashFilter.cropId);

    final totalSales = sales.fold<double>(0, (s, r) => s + r.amount);
    final totalExp = expenses.fold<double>(0, (s, r) => s + r.amount);
    final netProfit = totalSales - totalExp;
    final totalQty = sales.fold<double>(0, (s, r) => s + r.qty);

    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                maxWidth: constraints.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DashboardFilterBar(),
                  const SizedBox(height: 16),
                  _MetricGrid(
                    totalSales: totalSales, salesCount: sales.length,
                    totalExp: totalExp, expCount: expenses.length,
                    netProfit: netProfit, totalQty: totalQty,
                  ),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final isMobile = MediaQuery.of(context).size.width.isMobile;
                    if (isMobile) {
                      return Column(children: [
                        _ExpenseBreakdownCard(expenses: expenses),
                        const SizedBox(height: 12),
                        _FarmSummaryCard(sales: sales, expenses: expenses, farms: data.farms),
                      ]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _ExpenseBreakdownCard(expenses: expenses)),
                        const SizedBox(width: 16),
                        Expanded(child: _FarmSummaryCard(sales: sales, expenses: expenses, farms: data.farms)),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CardTitle(
                          title: 'Recent Activity',
                          trailing: Wrap(
                            spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SearchField(
                                hint: 'Search activity...',
                                onChanged: (v) => setState(() => _search = v),
                              ),
                              _PdfButton(
                                onTap: () => _exportPdf(
                                  context: context,
                                  sales: sales,
                                  expenses: expenses,
                                  farms: data.farms,
                                  mandis: data.mandis,
                                  crops: data.crops,
                                  totalSales: totalSales,
                                  totalExp: totalExp,
                                  netProfit: netProfit,
                                  totalQty: totalQty,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RecentActivityTable(
                          sales: sales, expenses: expenses,
                          farms: data.farms, mandis: data.mandis, crops: data.crops,
                          search: _search,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── PDF EXPORT ────────────────────────────────────────────────────────────────
Future<void> _exportPdf({
  required BuildContext context,
  required List<Sale> sales,
  required List<Expense> expenses,
  required List<Farm> farms,
  required List<Mandi> mandis,
  required List<Crop> crops,
  required double totalSales,
  required double totalExp,
  required double netProfit,
  required double totalQty,
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PdfProgressDialog(),
  );

  try {
    final pdfBytes = await _buildPdf(
      sales: sales, expenses: expenses, farms: farms,
      mandis: mandis, crops: crops, totalSales: totalSales,
      totalExp: totalExp, netProfit: netProfit, totalQty: totalQty,
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'shreeji_harvest_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.red),
    );
  }
}

Future<Uint8List> _buildPdf({
  required List<Sale> sales,
  required List<Expense> expenses,
  required List<Farm> farms,
  required List<Mandi> mandis,
  required List<Crop> crops,
  required double totalSales,
  required double totalExp,
  required double netProfit,
  required double totalQty,
}) async {
  // Load Unicode-capable fonts — supports ₹ and all Indian script glyphs
  final fontRegular = await PdfGoogleFonts.notoSansRegular();
  final fontBold    = await PdfGoogleFonts.notoSansBold();

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
  );

  const green   = PdfColor.fromInt(0xFF22C55E);
  const greenDk = PdfColor.fromInt(0xFF16A34A);
  const red     = PdfColor.fromInt(0xFFEF4444);
  const blue    = PdfColor.fromInt(0xFF3B82F6);
  const amber   = PdfColor.fromInt(0xFFF59E0B);
  const border  = PdfColor.fromInt(0xFFE5E7EB);
  const textPri = PdfColor.fromInt(0xFF111827);
  const textSec = PdfColor.fromInt(0xFF6B7280);

  String fName(String id) => AppUtils.farmName(farms, id);
  String mName(String id) => AppUtils.mandiName(mandis, id);
  String cName(String id) => AppUtils.cropName(crops, id);

  final combined = [
    ...sales.map((s) => _PdfRow(
        date: s.date, category: s.buyer, desc: s.deductDesc, farm: fName(s.farmId),
        mandi: mName(s.mandiId), crop: cName(s.cropId),
        qty: s.qty, amount: s.amount, isSale: true)),
    ...expenses.map((e) => _PdfRow(
        date: e.date, category: e.cat, desc: e.desc, farm: fName(e.farmId),
        mandi: mName(e.mandiId), crop: cName(e.cropId),
        qty: 0, amount: e.amount, isSale: false)),
  ]..sort((a, b) => b.date.compareTo(a.date));

  final Map<String, double> byCategory = {};
  for (final e in expenses) {
    byCategory[e.cat] = (byCategory[e.cat] ?? 0) + e.amount;
  }
  final catSorted = byCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final Map<String, double> farmSales = {};
  final Map<String, double> farmExp   = {};
  for (final s in sales)    farmSales[s.farmId] = (farmSales[s.farmId] ?? 0) + s.amount;
  for (final e in expenses) farmExp[e.farmId]   = (farmExp[e.farmId]   ?? 0) + e.amount;

  final generatedOn = AppUtils.formatDate(DateTime.now().toIso8601String());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Shreeji Harvest Hub',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: greenDk)),
                pw.Text('Harvest Management Report',
                    style: const pw.TextStyle(fontSize: 11, color: textSec)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Generated: $generatedOn',
                    style: const pw.TextStyle(fontSize: 10, color: textSec)),
                pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: const pw.TextStyle(fontSize: 10, color: textSec)),
              ]),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: border, thickness: 1),
          pw.SizedBox(height: 8),
        ],
      ),
      build: (ctx) => [
        // ── Summary Metrics
        pw.Text('Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textPri)),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          _pdfMetric('Total Sales',    AppUtils.formatCurrency(totalSales), green),
          pw.SizedBox(width: 8),
          _pdfMetric('Total Expenses', AppUtils.formatCurrency(totalExp),   red),
          pw.SizedBox(width: 8),
          _pdfMetric('Net Profit',     AppUtils.formatCurrency(netProfit),  netProfit >= 0 ? blue : amber),
          pw.SizedBox(width: 8),
          _pdfMetric('Production',     '${AppUtils.formatNumber(totalQty)} kg', amber),
        ]),
        pw.SizedBox(height: 20),

        // ── Farm-wise Summary
        if (farms.isNotEmpty) ...[
          pw.Text('Farm-wise Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textPri)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0FDF4)),
                children: [_pdfTH('Farm'), _pdfTH('Sales'), _pdfTH('Expenses'), _pdfTH('Net Profit')],
              ),
              ...farms.map((f) {
                final fs = farmSales[f.id] ?? 0;
                final fe = farmExp[f.id] ?? 0;
                final profit = fs - fe;
                return pw.TableRow(children: [
                  _pdfTD(f.name),
                  _pdfTD(AppUtils.formatCurrency(fs)),
                  _pdfTD(AppUtils.formatCurrency(fe)),
                  _pdfTDColor(AppUtils.formatCurrency(profit), profit >= 0 ? green : red),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // ── Expense Breakdown
        if (catSorted.isNotEmpty) ...[
          pw.Text('Expense Breakdown by Category',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textPri)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0FDF4)),
                children: [_pdfTH('Category'), _pdfTH('Amount'), _pdfTH('% of Total')],
              ),
              ...catSorted.map((entry) {
                final pct = totalExp > 0
                    ? (entry.value / totalExp * 100).toStringAsFixed(1)
                    : '0.0';
                return pw.TableRow(children: [
                  _pdfTD(entry.key),
                  _pdfTD(AppUtils.formatCurrency(entry.value)),
                  _pdfTD('$pct%'),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // ── Recent Activity
        pw.Text('Recent Activity',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textPri)),
        pw.SizedBox(height: 10),
        if (combined.isEmpty)
          pw.Text('No activity for this period.', style: const pw.TextStyle(color: textSec))
        else
          pw.Table(
            border: pw.TableBorder.all(color: border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3), // Date
              1: const pw.FlexColumnWidth(1.4), // Farm
              2: const pw.FlexColumnWidth(1.3), // Crop
              3: const pw.FlexColumnWidth(1.4), // Market
              4: const pw.FlexColumnWidth(1.6), // Buyer/Category
              5: const pw.FlexColumnWidth(1.0), // Qty
              6: const pw.FlexColumnWidth(1.8), // Description
              7: const pw.FlexColumnWidth(0.9), // Type
              8: const pw.FlexColumnWidth(1.3), // Amount
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0FDF4)),
                children: [
                  _pdfTH('Date'), _pdfTH('Farm'), _pdfTH('Crop'),
                  _pdfTH('Market'), _pdfTH('Buyer/Category'), _pdfTH('Qty (kg)'),
                  _pdfTH('Description'), _pdfTH('Type'), _pdfTH('Amount (Rs)'),
                ],
              ),
              ...combined.map((row) => pw.TableRow(children: [
                _pdfTD(AppUtils.formatDate(row.date)),
                _pdfTD(row.farm),
                _pdfTD(row.crop),
                _pdfTD(row.mandi),
                _pdfTD(row.category),
                _pdfTD(row.qty > 0 ? AppUtils.formatNumber(row.qty) : '-'),
                _pdfTD(row.desc.isNotEmpty ? row.desc : '-'),
                _pdfTDBadge(row.isSale ? 'Sale' : 'Exp', row.isSale ? green : amber),
                _pdfTDColor(
                  (row.isSale ? '+' : '-') + AppUtils.formatCurrency(row.amount),
                  row.isSale ? green : red,
                ),
              ])),
            ],
          ),
        pw.SizedBox(height: 20),
        pw.Divider(color: border),
        pw.SizedBox(height: 6),
        pw.Text('This report was auto-generated by Shreeji Harvest Hub.',
            style: const pw.TextStyle(fontSize: 9, color: textSec)),
      ],
    ),
  );

  return pdf.save();
}

// ── PDF cell helpers ──────────────────────────────────────────────────────────
const _pdfCellPad = pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5);
const _pdfTextSec = PdfColor.fromInt(0xFF6B7280);
const _pdfTextPri = PdfColor.fromInt(0xFF111827);

pw.Widget _pdfMetric(String label, String value, PdfColor color) =>
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF9FAFB),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _pdfTextSec)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );

pw.Widget _pdfTH(String text) => pw.Padding(
  padding: _pdfCellPad,
  child: pw.Text(text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfTextSec)),
);

pw.Widget _pdfTD(String text) => pw.Padding(
  padding: _pdfCellPad,
  child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: _pdfTextPri)),
);

pw.Widget _pdfTDColor(String text, PdfColor color) => pw.Padding(
  padding: _pdfCellPad,
  child: pw.Text(text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
);

pw.Widget _pdfTDBadge(String text, PdfColor color) {
  final bg = PdfColor(
    color.red   * 0.15 + 0.85,
    color.green * 0.15 + 0.85,
    color.blue  * 0.15 + 0.85,
  );
  return pw.Padding(
    padding: _pdfCellPad,
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color)),
    ),
  );
}

class _PdfRow {
  final String date, category, desc, farm, mandi, crop;
  final double qty, amount;
  final bool isSale;
  const _PdfRow({
    required this.date, required this.category, required this.desc,
    required this.farm, required this.mandi, required this.crop,
    required this.qty, required this.amount, required this.isSale,
  });
}

// ── PDF PROGRESS DIALOG ───────────────────────────────────────────────────────
class _PdfProgressDialog extends StatefulWidget {
  const _PdfProgressDialog();
  @override
  State<_PdfProgressDialog> createState() => _PdfProgressDialogState();
}

class _PdfProgressDialogState extends State<_PdfProgressDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _msgIndex = 0;

  static const _messages = [
    'Preparing report data…',
    'Building tables…',
    'Generating PDF…',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _anim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 0.5, end: 0.85).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 60),
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.shadowLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppColors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.blue, size: 24),
            ),
            const SizedBox(height: 16),
            const Text('Generating PDF',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, fontFamily: 'Sora')),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _messages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Sora'),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 6,
              decoration: BoxDecoration(
                  color: AppColors.surface2, borderRadius: BorderRadius.circular(3)),
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _anim.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.blue, AppColors.greenMid]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Align(
                alignment: Alignment.centerRight,
                child: Text('${(_anim.value * 100).toInt()}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary, fontFamily: 'Sora')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── EXPENSE BREAKDOWN CARD ────────────────────────────────────────────────────
class _ExpenseBreakdownCard extends StatelessWidget {
  final List<Expense> expenses;
  const _ExpenseBreakdownCard({required this.expenses});

  @override
  Widget build(BuildContext context) {
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final Map<String, double> byCategory = {};
    for (final e in expenses) {
      byCategory[e.cat] = (byCategory[e.cat] ?? 0) + e.amount;
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      AppColors.greenMid, AppColors.amber, AppColors.blue,
      AppColors.greenMuted, AppColors.red, AppColors.textTertiary,
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(title: 'Expense Breakdown'),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const EmptyState(icon: '📊', title: 'No expenses for this period')
          else
            ...sorted.asMap().entries.map((e) => ProgressRow(
              label: e.value.key,
              fraction: total > 0 ? e.value.value / total : 0,
              valueLabel: AppUtils.formatCurrency(e.value.value),
              barColor: colors[e.key % colors.length],
            )),
        ],
      ),
    );
  }
}

// ── FARM SUMMARY CARD ─────────────────────────────────────────────────────────
class _FarmSummaryCard extends StatelessWidget {
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<Farm> farms;
  const _FarmSummaryCard({required this.sales, required this.expenses, required this.farms});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> farmSales = {};
    final Map<String, double> farmExp = {};
    for (final s in sales) farmSales[s.farmId] = (farmSales[s.farmId] ?? 0) + s.amount;
    for (final e in expenses) farmExp[e.farmId] = (farmExp[e.farmId] ?? 0) + e.amount;
    final totalSales = sales.fold<double>(0, (s, r) => s + r.amount);
    final totalExp = expenses.fold<double>(0, (s, r) => s + r.amount);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(title: 'Farm-wise Summary'),
          const SizedBox(height: 16),
          if (farms.isEmpty)
            const EmptyState(icon: '🌾', title: 'No data for this period')
          else ...[
            ...farms.map((f) {
              final fs = farmSales[f.id] ?? 0;
              final fe = farmExp[f.id] ?? 0;
              final profit = fs - fe;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(f.name,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600, fontFamily: 'Sora'))),
                      Text(
                        profit >= 0
                            ? '▲ ${AppUtils.formatCurrency(profit)}'
                            : '▼ ${AppUtils.formatCurrency(profit.abs())}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            fontFamily: 'Sora',
                            color: profit >= 0 ? AppColors.greenMid : AppColors.red),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('Sales: ${AppUtils.formatCurrency(fs)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontFamily: 'Sora')),
                      const SizedBox(width: 12),
                      Text('Exp: ${AppUtils.formatCurrency(fe)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontFamily: 'Sora')),
                    ]),
                    const SizedBox(height: 8),
                    Container(height: 1, color: AppColors.border.withOpacity(0.5)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Expanded(child: Text('TOTAL NET',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                        fontFamily: 'Sora', color: AppColors.textSecondary, letterSpacing: 0.5))),
                Text(AppUtils.formatCurrency(totalSales - totalExp),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        fontFamily: 'Sora',
                        color: (totalSales - totalExp) >= 0 ? AppColors.greenMid : AppColors.red)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── DASHBOARD FILTER BAR ──────────────────────────────────────────────────────
class _DashboardFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final dashFilter = ref.watch(dashboardFilterProvider);
    final farmMandis = dashFilter.farmId.isEmpty
        ? data.mandis
        : data.mandis.where((m) => m.farmId == dashFilter.farmId || m.farmId.isEmpty).toList();
    final farmCrops = dashFilter.farmId.isEmpty
        ? data.crops
        : data.crops.where((c) => c.farmId == dashFilter.farmId).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.eco_rounded, size: 16, color: AppColors.greenMid),
            const SizedBox(width: 6),
            const Text('FARM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                fontFamily: 'Sora', color: AppColors.textSecondary, letterSpacing: 0.05)),
            const SizedBox(width: 8),
            _FilterDrop(
              value: dashFilter.farmId.isEmpty ? '' : dashFilter.farmId,
              items: [
                const DropdownMenuItem(value: '', child: Text('All farms')),
                ...data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
              ],
              onChanged: (v) => ref.read(dashboardFilterProvider.notifier).state =
                  dashFilter.copyWith(farmId: v ?? '', mandiId: '', cropId: ''),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.border2),
            const SizedBox(width: 12),
            const Icon(Icons.storefront_rounded, size: 16, color: AppColors.greenMid),
            const SizedBox(width: 6),
            const Text('MARKET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                fontFamily: 'Sora', color: AppColors.textSecondary, letterSpacing: 0.05)),
            const SizedBox(width: 8),
            _FilterDrop(
              value: dashFilter.mandiId.isEmpty ? '' : dashFilter.mandiId,
              items: [
                const DropdownMenuItem(value: '', child: Text('All markets')),
                ...farmMandis.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
              ],
              onChanged: (v) => ref.read(dashboardFilterProvider.notifier).state =
                  dashFilter.copyWith(mandiId: v ?? ''),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: AppColors.border2),
            const SizedBox(width: 12),
            const Icon(Icons.grass_rounded, size: 16, color: AppColors.greenMid),
            const SizedBox(width: 6),
            const Text('CROP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                fontFamily: 'Sora', color: AppColors.textSecondary, letterSpacing: 0.05)),
            const SizedBox(width: 8),
            _FilterDrop(
              value: dashFilter.cropId.isEmpty ? '' : dashFilter.cropId,
              items: [
                const DropdownMenuItem(value: '', child: Text('All crops')),
                ...farmCrops.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => ref.read(dashboardFilterProvider.notifier).state =
                  dashFilter.copyWith(cropId: v ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDrop extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _FilterDrop({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border2, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, items: items, onChanged: onChanged,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary, fontFamily: 'Sora'),
          dropdownColor: AppColors.surface,
          isDense: true, iconSize: 20,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── RECENT ACTIVITY TABLE ─────────────────────────────────────────────────────
class _RecentActivityTable extends StatelessWidget {
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<Farm> farms;
  final List<Mandi> mandis;
  final List<Crop> crops;
  final String search;

  const _RecentActivityTable({
    required this.sales, required this.expenses, required this.farms,
    required this.mandis, required this.crops, this.search = '',
  });

  String _farmName(String id)  => AppUtils.farmName(farms, id);
  String _mandiName(String id) => AppUtils.mandiName(mandis, id);
  String _cropName(String id)  => AppUtils.cropName(crops, id);

  @override
  Widget build(BuildContext context) {
    var combined = [
      ...sales.map((s) => _ActivityRow(
          date: s.date, category: s.buyer, description: s.deductDesc, farmId: s.farmId,
          mandiId: s.mandiId, cropId: s.cropId, qty: s.qty,
          amount: s.amount, isSale: true)),
      ...expenses.map((e) => _ActivityRow(
          date: e.date, category: e.cat, description: e.desc, farmId: e.farmId,
          mandiId: e.mandiId, cropId: e.cropId, qty: 0,
          amount: e.amount, isSale: false)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      combined = combined.where((row) =>
          row.category.toLowerCase().contains(q) ||
          row.description.toLowerCase().contains(q) ||
          _farmName(row.farmId).toLowerCase().contains(q) ||
          _mandiName(row.mandiId).toLowerCase().contains(q) ||
          _cropName(row.cropId).toLowerCase().contains(q)).toList();
    }

    if (combined.isEmpty) {
      return const EmptyState(icon: '📋', title: 'No activity for this period');
    }

    const cellStyle = TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: 'Sora');

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 56,
              columnSpacing: 24,
              horizontalMargin: 8,
              headingRowColor: WidgetStateProperty.all(Colors.transparent),
              columns: const [
                DataColumn(label: _TH('Date')),
                DataColumn(label: _TH('Farm')),
                DataColumn(label: _TH('Crop')),
                DataColumn(label: _TH('Market')),
                DataColumn(label: _TH('Buyer/Category')),
                DataColumn(label: _TH('Qty (kg)'), numeric: true),
                DataColumn(label: _TH('Description')),
                DataColumn(label: _TH('Type')),
                DataColumn(label: _TH('Amount (₹)'), numeric: true),
              ],
              rows: combined.map((row) => DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) return AppColors.greenPale;
                  return null;
                }),
                cells: [
                  DataCell(Text(AppUtils.formatDate(row.date), style: cellStyle)),
                  DataCell(Text(_farmName(row.farmId), style: cellStyle)),
                  DataCell(Text(_cropName(row.cropId), style: cellStyle)),
                  DataCell(Text(_mandiName(row.mandiId), style: cellStyle)),
                  DataCell(Text(row.category, style: cellStyle.copyWith(fontWeight: FontWeight.w500))),
                  DataCell(Text(row.qty > 0 ? AppUtils.formatNumber(row.qty) : '—',
                      style: cellStyle.copyWith(fontFamily: 'monospace'))),
                  DataCell(Text(row.description.isNotEmpty ? row.description : '—', style: cellStyle)),
                  DataCell(AppBadge(
                    label: row.isSale ? 'Sale' : 'Expense',
                    variant: row.isSale ? BadgeVariant.green : BadgeVariant.amber,
                  )),
                  DataCell(Text(
                    (row.isSale ? '' : '-') + AppUtils.formatCurrency(row.amount),
                    style: cellStyle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: row.isSale ? AppColors.greenMid : AppColors.red),
                  )),
                ],
              )).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityRow {
  final String date, category, description, farmId, mandiId, cropId;
  final double qty, amount;
  final bool isSale;
  const _ActivityRow({
    required this.date, required this.category, required this.description,
    required this.farmId, required this.mandiId, required this.cropId,
    required this.qty, required this.amount, required this.isSale,
  });
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
          fontFamily: 'Sora', color: AppColors.textTertiary, letterSpacing: 0.08));
}

class _PdfButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PdfButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
            SizedBox(width: 8),
            Text('PDF REPORT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    fontFamily: 'Sora', color: Colors.white, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}
// ── RESPONSIVE METRIC GRID ────────────────────────────────────────────────────
class _MetricGrid extends StatelessWidget {
  final double totalSales, totalExp, netProfit, totalQty;
  final int salesCount, expCount;
  const _MetricGrid({
    required this.totalSales, required this.salesCount,
    required this.totalExp,   required this.expCount,
    required this.netProfit,  required this.totalQty,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width.isMobile;
    final cards = [
      MetricCard(label: 'Total Sales',    value: AppUtils.formatCurrency(totalSales),
          sub: '$salesCount transactions', accent: MetricAccent.green),
      MetricCard(label: 'Total Expenses', value: AppUtils.formatCurrency(totalExp),
          sub: '$expCount entries',        accent: MetricAccent.red),
      MetricCard(label: 'Net Profit',     value: AppUtils.formatCurrency(netProfit),
          sub: netProfit >= 0 ? 'Surplus' : 'Deficit',
          accent: netProfit >= 0 ? MetricAccent.blue : MetricAccent.amber),
      MetricCard(label: 'Production',     value: '${AppUtils.formatNumber(totalQty)} kg',
          sub: 'Total dispatched',         accent: MetricAccent.amber),
    ];

    if (isMobile) {
      // 2×2 grid on mobile — no IntrinsicHeight to avoid divider artifact
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1]),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3]),
        ]),
      ]);
    }
    // 4-column row on tablet/desktop
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: cards[0]), const SizedBox(width: 12),
      Expanded(child: cards[1]), const SizedBox(width: 12),
      Expanded(child: cards[2]), const SizedBox(width: 12),
      Expanded(child: cards[3]),
    ]);
  }
}