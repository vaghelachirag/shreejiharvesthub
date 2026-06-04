import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'main_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dateFilterProvider);
    final dashFilter = ref.watch(dashboardFilterProvider);
    final data = ref.watch(appDataProvider);
    final notifier = ref.read(appDataProvider.notifier);

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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dashboard Filter Bar ──
          _DashboardFilterBar(),
          const SizedBox(height: 12),
          // ── Metrics Row — fixed-height equal cards matching Image 2 ──
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: MetricCard(
                  label: 'Total Sales',
                  value: AppUtils.formatCurrency(totalSales),
                  sub: '${sales.length} transactions',
                  accent: MetricAccent.green,
                )),
                const SizedBox(width: 10),
                Expanded(child: MetricCard(
                  label: 'Total Expenses',
                  value: AppUtils.formatCurrency(totalExp),
                  sub: '${expenses.length} entries',
                  accent: MetricAccent.red,
                )),
                const SizedBox(width: 10),
                Expanded(child: MetricCard(
                  label: 'Net Profit',
                  value: AppUtils.formatCurrency(netProfit),
                  sub: netProfit >= 0 ? 'Surplus' : 'Deficit',
                  accent: netProfit >= 0 ? MetricAccent.blue : MetricAccent.amber,
                )),
                const SizedBox(width: 10),
                Expanded(child: MetricCard(
                  label: 'Production',
                  value: '${AppUtils.formatNumber(totalQty)} kg',
                  sub: 'Total dispatched',
                  accent: MetricAccent.amber,
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Expense Breakdown + Farm Summary ──
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ExpenseBreakdownCard(expenses: expenses)),
                const SizedBox(width: 12),
                Expanded(child: _FarmSummaryCard(sales: sales, expenses: expenses, farms: data.farms)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Recent Activity ──
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardTitle(
                  title: 'Recent Activity',
                  trailing: _PdfButton(onTap: () {}),
                ),
                const SizedBox(height: 12),
                _RecentActivityTable(sales: sales, expenses: expenses, data: data),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── EXPENSE BREAKDOWN CARD ───────────────────────────────────────────────────
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(title: 'Expense Breakdown'),
          const SizedBox(height: 12),
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
    final t = Theme.of(context).textTheme;

    final Map<String, double> farmSales = {};
    final Map<String, double> farmExp = {};
    for (final s in sales) farmSales[s.farmId] = (farmSales[s.farmId] ?? 0) + s.amount;
    for (final e in expenses) farmExp[e.farmId] = (farmExp[e.farmId] ?? 0) + e.amount;

    final totalSales = sales.fold<double>(0, (s, r) => s + r.amount);
    final totalExp = expenses.fold<double>(0, (s, r) => s + r.amount);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(title: 'Farm-wise Summary'),
          const SizedBox(height: 12),
          if (farms.isEmpty)
            const EmptyState(icon: '🌾', title: 'No data for this period')
          else ...[
            ...farms.map((f) {
              final fs = farmSales[f.id] ?? 0;
              final fe = farmExp[f.id] ?? 0;
              final profit = fs - fe;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(f.name,
                            style: t.bodySmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        profit >= 0 ? '▲ ${AppUtils.formatCurrency(profit)}' : '▼ ${AppUtils.formatCurrency(profit.abs())}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: profit >= 0 ? AppColors.greenMid : AppColors.red),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('Sales: ${AppUtils.formatCurrency(fs)}',
                          style: t.labelSmall?.copyWith(color: AppColors.textTertiary)),
                      const SizedBox(width: 10),
                      Text('Exp: ${AppUtils.formatCurrency(fe)}',
                          style: t.labelSmall?.copyWith(color: AppColors.textTertiary)),
                    ]),
                    const SizedBox(height: 4),
                    Container(height: 1, color: AppColors.border),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(children: [
              const Expanded(
                  child: Text('TOTAL',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary))),
              Text(AppUtils.formatCurrency(totalSales - totalExp),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: (totalSales - totalExp) >= 0
                          ? AppColors.greenMid
                          : AppColors.red)),
            ]),
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
        : data.mandis
            .where((m) => m.farmId == dashFilter.farmId || m.farmId.isEmpty)
            .toList();
    final farmCrops = dashFilter.farmId.isEmpty
        ? data.crops
        : data.crops.where((c) => c.farmId == dashFilter.farmId).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.shadow,
      ),
      child: Row(
        children: [
          // ── Farm
          const Icon(Icons.eco_rounded, size: 14, color: AppColors.greenMid),
          const SizedBox(width: 5),
          const Text('FARM',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          _FilterDrop(
            value: dashFilter.farmId.isEmpty ? '' : dashFilter.farmId,
            items: [
              const DropdownMenuItem(value: '', child: Text('All farms')),
              ...data.farms.map(
                  (f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
            ],
            onChanged: (v) =>
                ref.read(dashboardFilterProvider.notifier).state =
                    dashFilter.copyWith(
                        farmId: v ?? '', mandiId: '', cropId: ''),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 22, color: AppColors.border2),
          const SizedBox(width: 14),
          // ── Mandi
          const Icon(Icons.store_outlined, size: 14, color: AppColors.greenMid),
          const SizedBox(width: 5),
          const Text('MANDI',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          _FilterDrop(
            value: dashFilter.mandiId.isEmpty ? '' : dashFilter.mandiId,
            items: [
              const DropdownMenuItem(value: '', child: Text('All markets')),
              ...farmMandis.map(
                  (m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
            ],
            onChanged: (v) =>
                ref.read(dashboardFilterProvider.notifier).state =
                    dashFilter.copyWith(mandiId: v ?? ''),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 22, color: AppColors.border2),
          const SizedBox(width: 14),
          // ── Crop
          const Icon(Icons.grass_outlined, size: 14, color: AppColors.greenMid),
          const SizedBox(width: 5),
          const Text('CROP',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          _FilterDrop(
            value: dashFilter.cropId.isEmpty ? '' : dashFilter.cropId,
            items: [
              const DropdownMenuItem(value: '', child: Text('All crops')),
              ...farmCrops.map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
            ],
            onChanged: (v) =>
                ref.read(dashboardFilterProvider.notifier).state =
                    dashFilter.copyWith(cropId: v ?? ''),
          ),
        ],
      ),
    );
  }
}

class _FilterDrop extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _FilterDrop(
      {required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border2, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontFamily: 'Sora'),
          dropdownColor: AppColors.surface,
          isDense: true,
          iconSize: 18,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── RECENT ACTIVITY TABLE ─────────────────────────────────────────────────────
class _RecentActivityTable extends StatelessWidget {
  final List<Sale> sales;
  final List<Expense> expenses;
  final AppDataState data;

  const _RecentActivityTable({
    required this.sales,
    required this.expenses,
    required this.data,
  });

  String _farmName(String id) =>
      data.farms.firstWhere((f) => f.id == id, orElse: () => Farm(id: '', name: '—')).name;
  String _mandiName(String id) =>
      data.mandis.firstWhere((m) => m.id == id, orElse: () => Mandi(id: '', farmId: '', name: '—')).name;
  String _cropName(String id) =>
      data.crops.firstWhere((c) => c.id == id, orElse: () => Crop(id: '', farmId: '', name: '—')).name;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final combined = [
      ...sales.map((s) => _ActivityRow(
            date: s.date, description: s.buyer, farmId: s.farmId,
            mandiId: s.mandiId, cropId: s.cropId, qty: s.qty,
            amount: s.amount, isSale: true,
          )),
      ...expenses.map((e) => _ActivityRow(
            date: e.date, description: e.desc, farmId: e.farmId,
            mandiId: e.mandiId, cropId: e.cropId, qty: 0,
            amount: e.amount, isSale: false,
          )),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (combined.isEmpty) {
      return const EmptyState(icon: '📋', title: 'No activity for this period');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 52,
        columnSpacing: 16,
        horizontalMargin: 4,
        headingRowColor: WidgetStateProperty.all(Colors.transparent),
        columns: const [
          DataColumn(label: _TH('Date')),
          DataColumn(label: _TH('Buyer / Description')),
          DataColumn(label: _TH('Farm')),
          DataColumn(label: _TH('Market')),
          DataColumn(label: _TH('Crop')),
          DataColumn(label: _TH('Qty (kg)'), numeric: true),
          DataColumn(label: _TH('Amount (₹)'), numeric: true),
          DataColumn(label: _TH('Type')),
        ],
        rows: combined.map((row) => DataRow(
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) return AppColors.greenPale;
            return null;
          }),
          cells: [
            DataCell(Text(AppUtils.formatDate(row.date), style: t.bodySmall)),
            DataCell(Text(row.description, style: t.bodySmall)),
            DataCell(Text(_farmName(row.farmId), style: t.bodySmall)),
            DataCell(Text(_mandiName(row.mandiId), style: t.bodySmall)),
            DataCell(Text(_cropName(row.cropId), style: t.bodySmall)),
            DataCell(Text(row.qty > 0 ? AppUtils.formatNumber(row.qty) : '—',
                style: t.bodySmall?.copyWith(fontFamily: 'monospace'))),
            DataCell(Text(
              (row.isSale ? '' : '-') + AppUtils.formatCurrency(row.amount),
              style: t.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: row.isSale ? AppColors.greenMid : AppColors.red),
            )),
            DataCell(AppBadge(
              label: row.isSale ? 'Sale' : 'Expense',
              variant: row.isSale ? BadgeVariant.green : BadgeVariant.amber,
            )),
          ],
        )).toList(),
      ),
    );
  }
}

class _ActivityRow {
  final String date, description, farmId, mandiId, cropId;
  final double qty, amount;
  final bool isSale;
  const _ActivityRow({
    required this.date, required this.description, required this.farmId,
    required this.mandiId, required this.cropId, required this.qty,
    required this.amount, required this.isSale,
  });
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.04));
  }
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
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('⬇ PDF Report',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}
