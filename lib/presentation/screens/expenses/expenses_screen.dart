import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/models/models.dart';
import '../../../data/providers/app_data_provider.dart';
import '../../widgets/common/common_widgets.dart';
import 'expense_form_dialog.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _State();
}

class _State extends ConsumerState<ExpensesScreen> {
  String _search = '', _catFilter = '', _farmFilter = '', _mandiFilter = '', _cropFilter = '';

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(dateFilterProvider);
    final data = ref.watch(appDataProvider);
    final notifier = ref.read(appDataProvider.notifier);
    final t = Theme.of(context).textTheme;

    var expenses = notifier.filteredExpenses(filter.range, filter.activeDate,
        farmId: _farmFilter, mandiId: _mandiFilter, cropId: _cropFilter, cat: _catFilter);

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      expenses = expenses.where((e) => e.desc.toLowerCase().contains(q) || e.cat.toLowerCase().contains(q)).toList();
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

    final totalAmt = expenses.fold<double>(0, (s, r) => s + r.amount);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Toolbar
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SearchField(hint: 'Search...', onChanged: (v) => setState(() => _search = v)),
          FilterDropdown(
            value: _catFilter.isEmpty ? '' : _catFilter,
            items: [
              const DropdownMenuItem(value: '', child: Text('All categories')),
              ...data.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => setState(() => _catFilter = v ?? ''),
          ),
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
          AddButton(label: '＋ Add Expense', onTap: () => showExpenseFormDialog(context, ref)),
          InkWell(
            onTap: () => _showCategoryManager(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(8)),
              child: const Text('⊕ Manage Categories',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(8)),
              child: const Text('⬇ PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Table
        Expanded(
          child: expenses.isEmpty
              ? const Center(child: EmptyState(icon: '📉', title: 'No expenses for this period'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
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
                        DataColumn(label: _TH('Description')),
                        DataColumn(label: _TH('Category')),
                        DataColumn(label: _TH('Farm')),
                        DataColumn(label: _TH('Market')),
                        DataColumn(label: _TH('Crop')),
                        DataColumn(label: _TH('Payment')),
                        DataColumn(label: _TH('Amount (₹)'), numeric: true),
                        DataColumn(label: _TH('')),
                      ],
                      rows: [
                        ...expenses.map((e) => DataRow(
                          color: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.hovered)) return AppColors.amberPale.withOpacity(0.5);
                            return null;
                          }),
                          cells: [
                            DataCell(Text(AppUtils.formatDate(e.date), style: t.bodySmall)),
                            DataCell(SizedBox(width: 160, child: Text(e.desc, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))),
                            DataCell(AppBadge(label: e.cat, variant: BadgeVariant.amber)),
                            DataCell(Text(farmName(e.farmId), style: t.bodySmall)),
                            DataCell(Text(mandiName(e.mandiId), style: t.bodySmall)),
                            DataCell(Text(cropName(e.cropId), style: t.bodySmall)),
                            DataCell(AppBadge(label: e.payMode,
                                variant: e.payMode == 'Cash' ? BadgeVariant.green
                                    : e.payMode == 'Online' ? BadgeVariant.blue
                                    : BadgeVariant.grey)),
                            DataCell(Text(AppUtils.formatCurrency(e.amount),
                                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              ActionIconButton(icon: Icons.edit_outlined, isDanger: false,
                                  onTap: () => showExpenseFormDialog(context, ref, e)),
                              const SizedBox(width: 4),
                              ActionIconButton(icon: Icons.delete_outline, isDanger: true,
                                  onTap: () async {
                                    final ok = await showConfirmDialog(context, message: 'Delete this expense?');
                                    if (ok) notifier.deleteExpense(e.id);
                                  }),
                            ])),
                          ],
                        )),
                        DataRow(
                          color: WidgetStateProperty.all(AppColors.amberPale.withOpacity(0.6)),
                          cells: [
                            const DataCell(Text('')), const DataCell(Text('')),
                            const DataCell(Text('')), const DataCell(Text('')),
                            const DataCell(Text('')), const DataCell(Text('')),
                            DataCell(Text('TOTAL', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                            DataCell(Text(AppUtils.formatCurrency(totalAmt),
                                style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: AppColors.amber))),
                            const DataCell(Text('')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  void _showCategoryManager(BuildContext context) {
    final data = ref.read(appDataProvider);
    final newCatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        final cats = ref.watch(appDataProvider).categories;
        return Dialog(child: Container(
          width: 380, padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Manage Categories', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                  Text(cat, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.amber)),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => ref.read(appDataProvider.notifier).deleteCategory(cat),
                    child: const Text('×', style: TextStyle(fontSize: 14, color: AppColors.amber)),
                  ),
                ]),
              )).toList(),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: TextField(
                controller: newCatCtrl,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'New category name',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber),
                onPressed: () {
                  if (newCatCtrl.text.trim().isNotEmpty) {
                    ref.read(appDataProvider.notifier).addCategory(newCatCtrl.text.trim());
                    newCatCtrl.clear();
                  }
                },
                child: const Text('Add'),
              ),
            ]),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight,
              child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))),
          ]),
        ));
      }),
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
