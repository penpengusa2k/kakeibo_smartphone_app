import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/screens/tag_detail_page.dart';
import 'package:kakeibo_smartphone_app/screens/total_amount_detail_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:kakeibo_smartphone_app/screens/balance_analysis_page.dart';

const double kSummaryTileHeight = 56;
const double kSummaryAmountLineHeight = 22;
const double kSummaryLabelFontSize = 12;
const double kSummaryAmountFontSize = 14;

enum _ViewType { month, year }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _focusedDate = DateTime.now();
  String _selectedTransactionType = 'expense';
  _ViewType _viewType = _ViewType.month;
  late PageController _pageController;

  bool _showSwipeHint = true;
  bool _userInteracted = false;

  static const List<Color> _gentleColors = [
    Color(0xFF64B5F6),
    Color(0xFFFFB74D),
    Color(0xFF9575CD),
    Color(0xFF4DB6AC),
    Color(0xFFFFF176),
    Color(0xFFF06292),
    Color(0xFF4DD0E1),
    Color(0xFFFF8A65),
    Color(0xFF90A4AE),
    Color(0xFFFFD54F),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _calculateInitialPage());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _calculateInitialPage() {
    final now = DateTime.now();
    return _viewType == _ViewType.month
        ? (now.year - 2000) * 12 + now.month - 1
        : now.year - 2000;
  }

  void _onPageChanged(int page) {
    setState(() {
      if (_viewType == _ViewType.month) {
        final year = 2000 + page ~/ 12;
        final month = page % 12 + 1;
        _focusedDate = DateTime(year, month);
      } else {
        _focusedDate = DateTime(2000 + page);
      }
      if (!_userInteracted) {
        _userInteracted = true;
        _showSwipeHint = false;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _focusedDate.year;
    int selectedMonth = _focusedDate.month;

    if (_viewType == _ViewType.month) {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('年月を選択', textAlign: TextAlign.center),
            content: SizedBox(
              width: 300,
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: selectedYear - 2000),
                      itemExtent: 40.0,
                      onSelectedItemChanged: (i) => selectedYear = 2000 + i,
                      children: List.generate(
                        DateTime.now().year - 2000 + 2,
                        (i) => Center(
                          child: Text('${2000 + i}年',
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                          initialItem: selectedMonth - 1),
                      itemExtent: 40.0,
                      onSelectedItemChanged: (i) => selectedMonth = i + 1,
                      children: List.generate(
                        12,
                        (i) => Center(
                          child: Text('${i + 1}月',
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('今月へ戻る'),
                onPressed: () => Navigator.of(context).pop(DateTime.now()),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  final oneYearLater = DateTime(now.year + 1, now.month, 1);
                  final selectedDate = DateTime(selectedYear, selectedMonth);
                  if (selectedDate.isAfter(oneYearLater)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('1年後より未来の月は選択できません')),
                    );
                    return;
                  }
                  Navigator.of(context).pop(selectedDate);
                },
                child: const Text('決定'),
              ),
            ],
          );
        },
      ).then((pickedDate) {
        if (pickedDate != null && pickedDate is DateTime) {
          setState(() {
            _focusedDate = pickedDate;
            _pageController
                .jumpToPage(_calculateInitialPageFromDate(pickedDate));
          });
        }
      });
    } else {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('年を選択', textAlign: TextAlign.center),
            content: SizedBox(
              width: 150,
              height: 200,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                    initialItem: selectedYear - 2000),
                itemExtent: 40.0,
                onSelectedItemChanged: (i) => selectedYear = 2000 + i,
                children: List.generate(
                  DateTime.now().year - 2000 + 2,
                  (i) => Center(
                    child: Text('${2000 + i}年',
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('今年へ戻る'),
                onPressed: () => Navigator.of(context).pop(DateTime.now()),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  final oneYearLater = DateTime(now.year + 1);
                  final selectedDate = DateTime(selectedYear);
                  if (selectedDate.isAfter(oneYearLater)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('1年後より未来の年は選択できません')),
                    );
                    return;
                  }
                  Navigator.of(context).pop(selectedDate);
                },
                child: const Text('決定'),
              ),
            ],
          );
        },
      ).then((pickedDate) {
        if (pickedDate != null && pickedDate is DateTime) {
          setState(() {
            _focusedDate = pickedDate;
            _pageController
                .jumpToPage(_calculateInitialPageFromDate(pickedDate));
          });
        }
      });
    }
  }

  int _calculateInitialPageFromDate(DateTime date) {
    return _viewType == _ViewType.month
        ? (date.year - 2000) * 12 + date.month - 1
        : date.year - 2000;
  }

  Map<String, int> _calculateSummary(List<Transaction> all) {
    int income = 0, expense = 0;
    final inPeriod = all.where((t) {
      if (_viewType == _ViewType.month) {
        return t.date.year == _focusedDate.year &&
            t.date.month == _focusedDate.month;
      } else {
        return t.date.year == _focusedDate.year;
      }
    });
    for (final t in inPeriod) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return {'income': income, 'expense': expense, 'balance': income - expense};
  }

  List<String> _collectTagsByType(TransactionViewModel vm, String type) {
    final tags = vm.transactions
        .where((t) => t.type == type)
        .map((t) => t.tag)
        .toSet()
        .toList()
      ..sort();
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<TransactionViewModel>(context);
    final summary = _calculateSummary(vm.transactions);

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: GestureDetector(
          onTap: () => _selectDate(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Opacity(opacity: 0, child: Icon(Icons.arrow_drop_down)),
              Text(
                _viewType == _ViewType.month
                    ? DateFormat('yyyy年MM月').format(_focusedDate)
                    : DateFormat('yyyy年').format(_focusedDate),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: _MonthYearSwitcherWrapper(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary（修正：Padding に `padding:` を追加）
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: '収入',
                      amount: summary['income']!,
                      color: Colors.green,
                      icon: Icons.trending_up,
                      tooltip: '収入の月別合計推移へ',
                      onTap: () {
                        final tags = _collectTagsByType(vm, 'income');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TotalAmountDetailPage(
                              transactions: vm.transactions
                                  .where((t) => t.type == 'income')
                                  .toList(),
                              initialFocusedMonth: _focusedDate,
                              selectedTransactionType: 'income',
                              allTags: tags,
                              tagColors: _gentleColors,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryTile(
                      label: '支出',
                      amount: summary['expense']!,
                      color: Colors.red,
                      icon: Icons.trending_down,
                      tooltip: '支出の月別合計推移へ',
                      onTap: () {
                        final tags = _collectTagsByType(vm, 'expense');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TotalAmountDetailPage(
                              transactions: vm.transactions
                                  .where((t) => t.type == 'expense')
                                  .toList(),
                              initialFocusedMonth: _focusedDate,
                              selectedTransactionType: 'expense',
                              allTags: tags,
                              tagColors: _gentleColors,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryTile(
                      label: '収支',
                      amount: summary['balance']!,
                      color: Colors.blue,
                      icon: Icons.stacked_line_chart,
                      tooltip: '収支推移（グラフ）へ',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BalanceAnalysisPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // タイプ切替
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 0.0),
            child: Center(
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _selectedTransactionType,
                onValueChanged: (v) {
                  if (v != null) setState(() => _selectedTransactionType = v);
                },
                children: const {
                  'expense': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('支出'),
                  ),
                  'income': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('収入'),
                  ),
                },
              ),
            ),
          ),
          Expanded(
            child: Listener(
              onPointerDown: (_) {
                if (!_userInteracted) {
                  setState(() {
                    _userInteracted = true;
                    _showSwipeHint = false;
                  });
                }
              },
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, page) {
                  final currentDate = _viewType == _ViewType.month
                      ? DateTime(2000 + page ~/ 12, page % 12 + 1)
                      : DateTime(2000 + page);
                  return _buildChartPage(
                    context,
                    vm,
                    currentDate,
                    showSwipeHint: _showSwipeHint && !_userInteracted,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPage(
    BuildContext context,
    TransactionViewModel vm,
    DateTime currentDate, {
    required bool showSwipeHint,
  }) {
    return _ChartPageContent(
      transactionViewModel: vm,
      currentDate: currentDate,
      selectedTransactionType: _selectedTransactionType,
      focusedDate: _focusedDate,
      viewType: _viewType,
      gentleColors: _gentleColors,
      showSwipeHint: showSwipeHint,
    );
  }
}

class _SummaryTile extends StatefulWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_SummaryTile> createState() => _SummaryTileState();
}

class _SummaryTileState extends State<_SummaryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tileColor = Theme.of(context).cardColor;

    return Semantics(
      button: true,
      hint: widget.tooltip,
      child: Material(
        color: tileColor,
        elevation: _pressed ? 2 : 0,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: kSummaryTileHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            textHeightBehavior: const TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(
                              fontSize: kSummaryLabelFontSize,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(widget.icon, size: 14, color: widget.color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: kSummaryAmountLineHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${Formatter.formatAmount(widget.amount)}円',
                                maxLines: 1,
                                softWrap: false,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: TextStyle(
                                  fontSize: kSummaryAmountFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: widget.color,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right,
                            size: 16, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartPageContent extends StatefulWidget {
  final TransactionViewModel transactionViewModel;
  final DateTime currentDate;
  final String selectedTransactionType;
  final DateTime focusedDate;
  final _ViewType viewType;
  final List<Color> gentleColors;
  final bool showSwipeHint;

  const _ChartPageContent({
    required this.transactionViewModel,
    required this.currentDate,
    required this.selectedTransactionType,
    required this.focusedDate,
    required this.viewType,
    required this.gentleColors,
    required this.showSwipeHint,
  });

  @override
  State<_ChartPageContent> createState() => _ChartPageContentState();
}

class _ChartPageContentState extends State<_ChartPageContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allTagsEver = widget.transactionViewModel.transactions
        .where((t) => t.type == widget.selectedTransactionType)
        .map((t) => t.tag)
        .toSet()
        .toList()
      ..sort();

    final filtered = widget.transactionViewModel.transactions.where((t) {
      final inPeriod = widget.viewType == _ViewType.month
          ? (t.date.year == widget.currentDate.year &&
              t.date.month == widget.currentDate.month)
          : (t.date.year == widget.currentDate.year);
      return inPeriod && t.type == widget.selectedTransactionType;
    }).toList();

    int totalAmount = 0;
    for (var t in filtered) {
      totalAmount += t.amount;
    }

    final Map<String, double> dataByCategory = {};
    for (var t in filtered) {
      dataByCategory[t.tag] = (dataByCategory[t.tag] ?? 0) + t.amount;
    }

    final sortedEntries = dataByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0), // ← 修正
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  SfCircularChart(
                    annotations: dataByCategory.isEmpty
                        ? <CircularChartAnnotation>[
                            CircularChartAnnotation(
                                widget: const Text('表示するデータがありません'))
                          ]
                        : null,
                    series: <CircularSeries>[
                      PieSeries<MapEntry<String, double>, String>(
                        dataSource: sortedEntries,
                        xValueMapper: (e, _) => e.key,
                        yValueMapper: (e, _) => e.value,
                        dataLabelMapper: (e, _) {
                          final total = totalAmount;
                          final p = total > 0 ? (e.value / total * 100) : 0.0;
                          final pt =
                              (p > 0 && p < 0.1) ? '<0.1%' : '${p.toStringAsFixed(1)}%';
                          return '${e.key}\n$pt';
                        },
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          labelPosition: ChartDataLabelPosition.outside,
                          connectorLineSettings: ConnectorLineSettings(
                            type: ConnectorType.curve,
                            length: '10%',
                          ),
                        ),
                        pointColorMapper: (e, i) => widget.gentleColors[
                            allTagsEver.indexOf(e.key) %
                                widget.gentleColors.length],
                      ),
                    ],
                  ),
                  if (widget.showSwipeHint) const _GraphSwipeHintOverlay(),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
            if (sortedEntries.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedEntries.length,
                itemBuilder: (context, index) {
                  final entry = sortedEntries[index];
                  final tag = entry.key;
                  final amount = entry.value;
                  final total = totalAmount;
                  final p = total > 0 ? (amount / total * 100) : 0.0;
                  final pText = (p > 0 && p < 0.1) ? '<0.1' : p.toStringAsFixed(1);

                  return Column(
                    children: [
                      ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TagDetailPage(
                                tagName: tag,
                                transactions: widget.transactionViewModel
                                    .transactions
                                    .where((t) =>
                                        t.tag == tag &&
                                        t.type == widget.selectedTransactionType)
                                    .toList(),
                                initialFocusedMonth: widget.focusedDate,
                                selectedTransactionType:
                                    widget.selectedTransactionType,
                                tagColor: widget.gentleColors[
                                    allTagsEver.indexOf(tag) %
                                        widget.gentleColors.length],
                              ),
                            ),
                          );
                        },
                        leading: Container(
                          width: 50,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.gentleColors[
                                allTagsEver.indexOf(tag) %
                                    widget.gentleColors.length],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$pText%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(tag),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${Formatter.formatAmount(amount.toInt())}円',
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GraphSwipeHintOverlay extends StatelessWidget {
  const _GraphSwipeHintOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: 100.0), // ← 修正
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, color: Colors.white),
                  SizedBox(width: 8),
                  Text('左右にスワイプ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthYearSwitcherWrapper extends StatefulWidget {
  const _MonthYearSwitcherWrapper({super.key});

  @override
  State<_MonthYearSwitcherWrapper> createState() =>
      _MonthYearSwitcherWrapperState();
}

class _MonthYearSwitcherWrapperState
    extends State<_MonthYearSwitcherWrapper> {
  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AnalyticsPageState>();
    if (state == null) return const SizedBox.shrink();
    return _MonthYearSwitcher(
      viewType: state._viewType,
      onToggle: () {
        state.setState(() {
          state._viewType =
              state._viewType == _ViewType.month ? _ViewType.year : _ViewType.month;
          state._focusedDate = DateTime.now();
          state._pageController.jumpToPage(state._calculateInitialPage());
        });
      },
    );
  }
}

class _MonthYearSwitcher extends StatelessWidget {
  final _ViewType viewType;
  final VoidCallback onToggle;
  const _MonthYearSwitcher({
    required this.viewType,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final active = Colors.orange.shade700;
    final inactive =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.black87;

    const double containerWidth = 84;
    const double containerHeight = 40;
    const double leftSlot = 20.0;
    const double rightSlot = 40.0;
    const double badgeSize = 38.0;

    final bool isMonth = viewType == _ViewType.month;

    final double monthTop = isMonth ? 0.0 : -6.0;
    final double monthScale = isMonth ? 1.0 : 0.80;
    final double monthOpacity = isMonth ? 1.0 : 0.55;

    final double yearTop = isMonth ? -6.0 : 0.0;
    final double yearScale = isMonth ? 0.80 : 1.0;
    final double yearOpacity = isMonth ? 0.55 : 1.0;

    final monthBadge = _AnimatedBadge(
      key: const ValueKey('month'),
      left: leftSlot,
      top: monthTop,
      label: '月',
      isActive: isMonth,
      activeColor: active,
      inactiveColor: inactive,
      scale: monthScale,
      opacity: monthOpacity,
      size: badgeSize,
    );

    final yearBadge = _AnimatedBadge(
      key: const ValueKey('year'),
      left: rightSlot,
      top: yearTop,
      label: '年',
      isActive: !isMonth,
      activeColor: active,
      inactiveColor: inactive,
      scale: yearScale,
      opacity: yearOpacity,
      size: badgeSize,
    );

    final children =
        isMonth ? <Widget>[yearBadge, monthBadge] : <Widget>[monthBadge, yearBadge];

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: containerWidth,
        height: containerHeight,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }
}

class _AnimatedBadge extends StatelessWidget {
  final double left;
  final double top;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final double scale;
  final double opacity;
  final double size;

  const _AnimatedBadge({
    super.key,
    required this.left,
    required this.top,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.scale,
    required this.opacity,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      left: left,
      top: top,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        opacity: opacity,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          scale: scale,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, size: size - 8, color: color),
                Positioned(
                  bottom: 6,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
