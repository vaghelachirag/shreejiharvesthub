import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'sale_form_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(dateFilterProvider);
    final data = ref.watch(appDataProvider);
    final notifier = ref.read(appDataProvider.notifier);
    final t = Theme.of(context).textTheme;

    var sales = notifier.filteredSales(filter.range, filter.activeDate,
        farmId: _farmFilter, mandiId: _mandiFilter, cropId: _cropFilter);

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      sales = sales.where((s) => s.buyer.toLowerCase().contains(q)).toList();
    }

    String farmName(String id) =>
        data.farms.firstWhere((f) => f.id == id, orElse: () => Farm(id: '', name: '—')).name;
    String mandiName(String id) =>
        data.mandis.firstWhere((m) => m.id == id, orElse: () => Mandi(id: '', farmId: '', name: '—')).name;
    String cropName(String id) =>
        data.crops.firstWhere((c) => c.id == id, orElse: () => Crop(id: '', farmId: '', name: '—')).name;

    final farmMandis = _farmFilter.isEmpty
        ? data.mandis
        : data.mandis.where((m) => m.farmId == _farmFilter).toList();

    final totalAmt = sales.fold<double>(0, (s, r) => s + r.amount);
    final totalQty = sales.fold<double>(0, (s, r) => s + r.qty);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Wrap(
            spacing: 8, runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SearchField(hint: 'Search buyer...', onChanged: (v) => setState(() => _search = v)),
              FilterDropdown(
                value: _farmFilter.isEmpty ? '' : _farmFilter,
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Farms')),
                  ...data.farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                ],
                onChanged: (v) => setState(() { _farmFilter = v ?? ''; _mandiFilter = ''; }),
              ),
              FilterDropdown(
                value: _mandiFilter.isEmpty ? '' : _mandiFilter,
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Markets')),
                  ...farmMandis.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))),
                ],
                onChanged: (v) => setState(() => _mandiFilter = v ?? ''),
              ),
              FilterDropdown(
                value: _cropFilter.isEmpty ? '' : _cropFilter,
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Crops')),
                  ...data.crops.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _cropFilter = v ?? ''),
              ),
              AddButton(label: '＋ Add Sale', onTap: () => showSaleFormDialog(context, ref)),
              _PdfBtn(),
            ],
          ),
          const SizedBox(height: 12),
          // Table
          Expanded(
            child: sales.isEmpty
                ? const Center(child: EmptyState(icon: '💰', title: 'No sales for this period'))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 52,
                            columnSpacing: 14,
                            horizontalMargin: 4,
                            headingRowColor: WidgetStateProperty.all(Colors.transparent),
                            columns: const [
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
                            rows: [
                              ...sales.map((s) => DataRow(
                                    color: WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(WidgetState.hovered)) return AppColors.greenPale;
                                      return null;
                                    }),
                                    cells: [
                                      DataCell(Text(AppUtils.formatDate(s.date), style: t.bodySmall)),
                                      DataCell(Text(s.buyer, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
                                      DataCell(Text(farmName(s.farmId), style: t.bodySmall)),
                                      DataCell(Text(mandiName(s.mandiId), style: t.bodySmall)),
                                      DataCell(Text(cropName(s.cropId), style: t.bodySmall)),
                                      DataCell(Text(AppUtils.formatNumber(s.qty), style: t.bodySmall)),
                                      DataCell(Text(s.rate > 0 ? '₹${s.rate}' : 'Mixed', style: t.bodySmall)),
                                      DataCell(Text(s.deduction > 0 ? '-${AppUtils.formatCurrency(s.deduction)}' : '—', style: t.bodySmall)),
                                      DataCell(AppBadge(
                                        label: s.payMode,
                                        variant: s.payMode == 'Cash' ? BadgeVariant.green
                                            : s.payMode == 'Online' ? BadgeVariant.blue
                                            : BadgeVariant.amber,
                                      )),
                                      DataCell(Text(AppUtils.formatCurrency(s.amount),
                                          style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        ActionIconButton(icon: Icons.edit_outlined, onTap: () => showSaleFormDialog(context, ref, s), isDanger: false),
                                        const SizedBox(width: 4),
                                        ActionIconButton(icon: Icons.delete_outline, isDanger: true, onTap: () async {
                                          final ok = await showConfirmDialog(context,
                                              message: 'Delete this sale entry?');
                                          if (ok) notifier.deleteSale(s.id);
                                        }),
                                      ])),
                                    ],
                                  )),
                              // Totals row
                              DataRow(
                                color: WidgetStateProperty.all(AppColors.greenPale),
                                cells: [
                                  const DataCell(Text('')), const DataCell(Text('')),
                                  const DataCell(Text('')), const DataCell(Text('')),
                                  DataCell(Text('TOTAL', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                                  DataCell(Text(AppUtils.formatNumber(totalQty),
                                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                                  const DataCell(Text('')), const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  DataCell(Text(AppUtils.formatCurrency(totalAmt),
                                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.greenMid))),
                                  const DataCell(Text('')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 0.04));
}

class _PdfBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 'auto' == 'auto' ? 0 : 0),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
            child: const Text('⬇ PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      );
}
