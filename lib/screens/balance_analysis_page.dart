// ignore_for_file: avoid_print

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';

enum Period { day, month, year }

// ===== Calendar-like constants (compacted) =====
const Color kBandBgColor = Color(0xFFF2F3F5);

const double kTableHeaderMinH = 26;
const double kTableHeaderMaxH = 28;
const double kDateHeaderMinH = 24;
const double kDateHeaderMaxH = 26;

const double kTxRowHeight = 40;

const double kSummaryTileHeight = 48;
const double kSummaryAmountLineHeight = 18;
const double kSummaryLabelFontSize = 11;
const double kSummaryAmountFontSize = 13;

class BalanceAnalysisPage extends StatefulWidget {
  const BalanceAnalysisPage({super.key});

  @override
  State<BalanceAnalysisPage> createState() => _BalanceAnalysisPageState();
}

class _BalanceAnalysisPageState extends State<BalanceAnalysisPage> {
  DateTime _startDate;
  DateTime _endDate;
  Period _selectedPeriod = Period.month;

  _BalanceAnalysisPageState()
      : _startDate = DateTime.now(),
        _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateDateRange();
  }

  void _updateDateRange() {
    final now = DateTime.now();
    setState(() {
      switch (_selectedPeriod) {
        case Period.day:
          _startDate =
              DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
          _endDate = DateTime(now.year, now.month, now.day);
          break;
        case Period.month:
          _startDate = DateTime(now.year, now.month - 6, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case Period.year:
          _startDate = DateTime(now.year - 2, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
      }
    });
  }

  Future<void> _selectDay(BuildContext context, {required bool isStartDate}) async {
    final initialDate = isStartDate ? _startDate : _endDate;

    final pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        int selectedYear = initialDate.year;
        int selectedMonth = initialDate.month;
        int selectedDay = initialDate.day;
        final now = DateTime.now();

        return StatefulBuilder(
          builder: (context, setState) {
            final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
            if (selectedDay > daysInMonth) selectedDay = daysInMonth;

            return AlertDialog(
              title: Text(isStartDate ? '開始日を選択' : '終了日を選択', textAlign: TextAlign.center),
              content: SizedBox(
                width: 300,
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: selectedYear - 2000),
                        itemExtent: 40.0,
                        onSelectedItemChanged: (int index) {
                          setState(() => selectedYear = 2000 + index);
                        },
                        children: List<Widget>.generate(
                          now.year - 2000 + 2,
                          (int index) => Center(child: Text('${2000 + index}年')),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: selectedMonth - 1),
                        itemExtent: 40.0,
                        onSelectedItemChanged: (int index) {
                          setState(() => selectedMonth = index + 1);
                        },
                        children:
                            List<Widget>.generate(12, (int i) => Center(child: Text('${i + 1}月'))),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController:
                            FixedExtentScrollController(initialItem: selectedDay - 1),
                        itemExtent: 40.0,
                        onSelectedItemChanged: (int index) => selectedDay = index + 1,
                        children: List<Widget>.generate(
                          daysInMonth,
                          (int index) => Center(child: Text('${index + 1}日')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(DateTime(selectedYear, selectedMonth, selectedDay)),
                  child: const Text('決定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedDate != null) {
      if (isStartDate && pickedDate.isAfter(_endDate)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('開始日は終了日より前に設定してください。')));
        return;
      }
      if (!isStartDate && pickedDate.isBefore(_startDate)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('終了日は開始日より後に設定してください。')));
        return;
      }
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Future<void> _selectPeriod(BuildContext context, {required bool isStartDate}) async {
    final now = DateTime.now();
    final initialDate = isStartDate ? _startDate : _endDate;
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isStartDate ? '開始期間を選択' : '終了期間を選択', textAlign: TextAlign.center),
          content: SizedBox(
            width: 300,
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController:
                        FixedExtentScrollController(initialItem: selectedYear - 2000),
                    itemExtent: 40.0,
                    onSelectedItemChanged: (int index) => selectedYear = 2000 + index,
                    children: List<Widget>.generate(
                      now.year - 2000 + 2,
                      (int index) => Center(
                        child: Text('${2000 + index}年', style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
                ),
                if (_selectedPeriod != Period.year)
                  Expanded(
                    child: CupertinoPicker(
                      scrollController:
                          FixedExtentScrollController(initialItem: selectedMonth - 1),
                      itemExtent: 40.0,
                      onSelectedItemChanged: (int index) => selectedMonth = index + 1,
                      children: List<Widget>.generate(
                        12,
                        (int index) =>
                            Center(child: Text('${index + 1}月', style: const TextStyle(fontSize: 20))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
            TextButton(
              onPressed: () {
                DateTime selectedDate;
                if (_selectedPeriod == Period.year) {
                  selectedDate = DateTime(selectedYear);
                } else {
                  selectedDate = DateTime(selectedYear, selectedMonth);
                }
                Navigator.of(context).pop(selectedDate);
              },
              child: const Text('決定'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result != null) {
      DateTime newDate = result;

      if (isStartDate && newDate.isAfter(_endDate)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('開始期間は終了期間より前に設定してください。')));
        return;
      }
      if (!isStartDate && newDate.isBefore(_startDate)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('終了期間は開始期間より後に設定してください。')));
        return;
      }

      setState(() {
        if (isStartDate) {
          _startDate = _selectedPeriod == Period.year
              ? DateTime(newDate.year, 1, 1)
              : DateTime(newDate.year, newDate.month, 1);
        } else {
          _endDate = _selectedPeriod == Period.year
              ? DateTime(newDate.year, 12, 31)
              : DateTime(newDate.year, newDate.month + 1, 0);
        }
      });
    }
  }

  List<ChartData> _getChartData(List<Transaction> txs) {
    final Map<String, Map<String, int>> agg = {};

    final filtered = txs.where((t) {
      return t.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();

    for (var t in filtered) {
      String key;
      switch (_selectedPeriod) {
        case Period.day:
          key = DateFormat('MM/dd').format(t.date);
          break;
        case Period.month:
          key = DateFormat('yy/MM').format(t.date);
          break;
        case Period.year:
          key = DateFormat('yyyy').format(t.date);
          break;
      }
      agg.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (t.type == 'income') {
        agg[key]!['income'] = (agg[key]!['income'] ?? 0) + t.amount;
      } else {
        agg[key]!['expense'] = (agg[key]!['expense'] ?? 0) + t.amount;
      }
    }

    final List<String> keys = [];
    DateTime cur = _startDate;
    while (cur.isBefore(_endDate) || cur.isAtSameMomentAs(_endDate)) {
      switch (_selectedPeriod) {
        case Period.day:
          keys.add(DateFormat('MM/dd').format(cur));
          cur = cur.add(const Duration(days: 1));
          break;
        case Period.month:
          keys.add(DateFormat('yy/MM').format(cur));
          cur = DateTime(cur.year, cur.month + 1, 1);
          break;
        case Period.year:
          keys.add(DateFormat('yyyy').format(cur));
          cur = DateTime(cur.year + 1, 1, 1);
          break;
      }
    }

    return keys
        .map((k) => ChartData(k, agg[k]?['income'] ?? 0, agg[k]?['expense'] ?? 0,
            (agg[k]?['income'] ?? 0) - (agg[k]?['expense'] ?? 0)))
        .toList();
  }

  Widget _buildDatePickerButton({
    required String label,
    required String valueText,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 34,
            child: Center(
              child: Text(valueText, style: const TextStyle(fontSize: 15, color: Colors.black87)),
            ),
          ),
        ),
        Positioned(
          top: -8,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ),
        ),
      ],
    );
  }

  ({int income, int expense, int balance}) _sumForRange(List<Transaction> txs) {
    final inRange = txs
        .where((t) => !t.date.isBefore(_startDate) && !t.date.isAfter(_endDate))
        .toList();
    final income = inRange.where((t) => t.type == 'income').fold<int>(0, (s, t) => s + t.amount);
    final expense = inRange.where((t) => t.type == 'expense').fold<int>(0, (s, t) => s + t.amount);
    return (income: income, expense: expense, balance: income - expense);
  }

  Map<DateTime, List<Transaction>> _groupByDay(List<Transaction> txs) {
    final inRange =
        txs.where((t) => !t.date.isBefore(_startDate) && !t.date.isAfter(_endDate)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final map = <DateTime, List<Transaction>>{};
    for (final t in inRange) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      (map[key] ??= []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final txs = context.select<TransactionViewModel, List<Transaction>>((vm) => vm.transactions);
    final data = _getChartData(txs);

    String periodText;
    switch (_selectedPeriod) {
      case Period.day:
        periodText = '日';
        break;
      case Period.month:
        periodText = '月';
        break;
      case Period.year:
        periodText = '年';
        break;
    }

    final periodToggle = TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        fixedSize: const Size(72, 30),
      ),
      icon: const Icon(Icons.sync, size: 16),
      label: Text(periodText, style: const TextStyle(fontSize: 13)),
      onPressed: () {
        setState(() {
          final currentIndex = Period.values.indexOf(_selectedPeriod);
          final nextIndex = (currentIndex + 1) % Period.values.length;
          _selectedPeriod = Period.values[nextIndex];
          _updateDateRange();
        });
      },
    );

    // Summary numbers
    final summary = _sumForRange(txs);

    // Grouped table
    final grouped = _groupByDay(txs);
    final sectionDates = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    // Date picker texts
    String startDateText, endDateText;
    switch (_selectedPeriod) {
      case Period.day:
        startDateText = DateFormat('yyyy/MM/dd').format(_startDate);
        endDateText = DateFormat('yyyy/MM/dd').format(_endDate);
        break;
      case Period.month:
        startDateText = DateFormat('yyyy/MM').format(_startDate);
        endDateText = DateFormat('yyyy/MM').format(_endDate);
        break;
      case Period.year:
        startDateText = DateFormat('yyyy').format(_startDate);
        endDateText = DateFormat('yyyy').format(_endDate);
        break;
    }

    final datePickerWidget = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: _buildDatePickerButton(
              label: '開始',
              valueText: startDateText,
              onPressed: () {
                if (_selectedPeriod == Period.day) {
                  _selectDay(context, isStartDate: true);
                } else {
                  _selectPeriod(context, isStartDate: true);
                }
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.0),
            child: Text('～', style: TextStyle(fontSize: 15, color: Colors.black54)),
          ),
          Expanded(
            child: _buildDatePickerButton(
              label: '終了',
              valueText: endDateText,
              onPressed: () {
                if (_selectedPeriod == Period.day) {
                  _selectDay(context, isStartDate: false);
                } else {
                  _selectPeriod(context, isStartDate: false);
                }
              },
            ),
          ),
        ],
      ),
    );

    // Graph height: compact & responsive
    final screenH = MediaQuery.of(context).size.height;
    final graphHeight = (screenH * 0.24).clamp(160.0, 220.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '収支推移',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
        ),
        centerTitle: true,
        actions: [Padding(padding: const EdgeInsets.only(right: 6.0), child: periodToggle)],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            datePickerWidget,
            // Graph (compact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SizedBox(
                    height: graphHeight,
                    width: double.infinity,
                    child: data.isEmpty
                        ? const Center(child: Text('データがありません'))
                        : _StickyYAxisScrollableChart(data: data, period: _selectedPeriod),
                  ),
                ),
              ),
            ),
            // Summary band (compact)
            Container(
              color: kBandBgColor,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: kSummaryTileHeight,
                        child: _SummaryTileFrame(
                          label: '収入',
                          color: Colors.green,
                          icon: Icons.trending_up,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${Formatter.formatAmount(summary.income)}円',
                              maxLines: 1,
                              softWrap: false,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: const TextStyle(
                                fontSize: kSummaryAmountFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: kSummaryTileHeight,
                        child: _SummaryTileFrame(
                          label: '支出',
                          color: Colors.red,
                          icon: Icons.trending_down,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${Formatter.formatAmount(summary.expense)}円',
                              maxLines: 1,
                              softWrap: false,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: const TextStyle(
                                fontSize: kSummaryAmountFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: kSummaryTileHeight,
                        child: _SummaryTileFrame(
                          label: '収支',
                          color: Colors.blue,
                          icon: Icons.stacked_line_chart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${Formatter.formatAmount(summary.balance)}円',
                              maxLines: 1,
                              softWrap: false,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: const TextStyle(
                                fontSize: kSummaryAmountFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Table (scrolls)
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Column header
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SimpleHeaderDelegate(
                      minExtent: kTableHeaderMinH,
                      maxExtent: kTableHeaderMaxH,
                      builder: (context, shrinkOffset, overlapsContent) {
                        return Container(
                          color: kBandBgColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: const [
                              Expanded(
                                flex: 4,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('タグ',
                                      style:
                                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('メモ',
                                      style:
                                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('金額',
                                      style:
                                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (sectionDates.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('この期間の取引はありません。')),
                    )
                  else ...[
                    for (final d in sectionDates) ...[
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SimpleHeaderDelegate(
                          minExtent: kDateHeaderMinH,
                          maxExtent: kDateHeaderMaxH,
                          builder: (context, shrinkOffset, overlapsContent) {
                            return Container(
                              color: kBandBgColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                DateFormat('MM月dd日（E）', 'ja').format(d),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            );
                          },
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final t = grouped[d]![index];
                            return _TxRowAnalysis(transaction: t);
                          },
                          childCount: grouped[d]!.length,
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fixed Y-axis + scrollable chart body
// ─────────────────────────────────────────────────────────────
class _StickyYAxisScrollableChart extends StatelessWidget {
  const _StickyYAxisScrollableChart({
    required this.data,
    required this.period,
  });

  final List<ChartData> data;
  final Period period;

  static const double _leftReserved = 14;
  double _bottomReserved(double labelAngleDeg) => labelAngleDeg == 0 ? 22 : 36;

  @override
  Widget build(BuildContext context) {
    final labels = data.map((e) => e.date).toList();
    final incomes = data.map((e) => e.income.toDouble()).toList();
    final expenses = data.map((e) => (-e.expense).toDouble()).toList();
    final cumulative = <double>[];

    double run = 0;
    for (int i = 0; i < labels.length; i++) {
      run += incomes[i] + expenses[i];
      cumulative.add(run);
    }

    double labelAngle = 0;
    int labelStep = 1;
    if (period == Period.day) {
      labelAngle = -45;
      if (labels.length > 10) labelStep = 2;
    }

    double maxAbsY = 0;
    for (int i = 0; i < labels.length; i++) {
      maxAbsY = max(maxAbsY, incomes[i].abs());
      maxAbsY = max(maxAbsY, expenses[i].abs());
      maxAbsY = max(maxAbsY, cumulative[i].abs());
    }
    if (maxAbsY == 0) maxAbsY = 1000;
    maxAbsY *= 1.1;

    final interval = _niceGridInterval(maxAbsY);
    final step = period == Period.day ? 52.0 : (period == Period.month ? 66.0 : 90.0);

    return LayoutBuilder(builder: (context, constraints) {
      final plotWidth = max(constraints.maxWidth - _leftReserved, step * labels.length);

      final axisChart = LineChart(
        LineChartData(
          minX: 0,
          maxX: 1,
          minY: -maxAbsY,
          maxY: maxAbsY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 1, color: Colors.black12),
          ),
          extraLinesData:
              ExtraLinesData(horizontalLines: [HorizontalLine(y: 0, color: Colors.black26, strokeWidth: 1)]),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles:
                  SideTitles(showTitles: false, reservedSize: _bottomReserved(labelAngle)),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: _leftReserved,
                interval: interval,
                getTitlesWidget: (v, meta) {
                  if (v == 0) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Transform.translate(
                          offset: const Offset(0, -6),
                          child: const Text(
                            '0',
                            textAlign: TextAlign.right,
                            textHeightBehavior: TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(fontSize: 11, height: 1.0),
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              top: BorderSide(color: Colors.black12, width: 1),
              right: BorderSide(color: Colors.transparent, width: 1),
              left: BorderSide(color: Colors.black12, width: 1),
              bottom: BorderSide(color: Colors.black12, width: 1),
            ),
          ),
          lineBarsData: const [],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      );

      final scrollChart = _UnifiedLineChart(
        labels: labels,
        incomes: incomes,
        expenses: expenses,
        balances: cumulative,
        maxAbsY: maxAbsY,
        labelAngleDeg: labelAngle,
        labelStep: labelStep,
        showLeftAxis: false,
        leftReserved: _leftReserved,
        bottomReserved: _bottomReserved(labelAngle),
        drawLeftBorder: false,
        horizontalInterval: interval,
        minY: -maxAbsY,
        maxY: maxAbsY,
      );

      return Row(
        children: [
          SizedBox(width: _leftReserved, child: axisChart),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(width: plotWidth, child: scrollChart),
            ),
          ),
        ],
      );
    });
  }
}

class _UnifiedLineChart extends StatelessWidget {
  const _UnifiedLineChart({
    required this.labels,
    required this.incomes,
    required this.expenses,
    required this.balances,
    required this.maxAbsY,
    required this.labelAngleDeg,
    required this.labelStep,
    this.showLeftAxis = true,
    this.leftReserved = 44,
    this.bottomReserved = 24,
    this.drawLeftBorder = true,
    required this.horizontalInterval,
    required this.minY,
    required this.maxY,
  });

  final List<String> labels;
  final List<double> incomes;
  final List<double> expenses; // negative
  final List<double> balances; // cumulative
  final double maxAbsY;
  final double labelAngleDeg;
  final int labelStep;
  final double minY;
  final double maxY;

  final bool showLeftAxis;
  final double leftReserved;
  final double bottomReserved;
  final bool drawLeftBorder;
  final double horizontalInterval;

  @override
  Widget build(BuildContext context) {
    const netColor = Colors.blue;
    final nf = NumberFormat('#,###');

    final incomeBars = <LineChartBarData>[];
    final expenseBars = <LineChartBarData>[];
    for (int i = 0; i < labels.length; i++) {
      if (incomes[i] != 0) {
        incomeBars.add(
          LineChartBarData(
            spots: [FlSpot(i.toDouble(), 0), FlSpot(i.toDouble(), incomes[i])],
            isCurved: false,
            color: Colors.green,
            barWidth: 10,
            dotData: FlDotData(show: false),
            isStrokeCapRound: false,
          ),
        );
      }
      if (expenses[i] != 0) {
        expenseBars.add(
          LineChartBarData(
            spots: [FlSpot(i.toDouble(), 0), FlSpot(i.toDouble(), expenses[i])],
            isCurved: false,
            color: Colors.red,
            barWidth: 10,
            dotData: FlDotData(show: false),
            isStrokeCapRound: false,
          ),
        );
      }
    }

    final balanceLine = LineChartBarData(
      spots: [for (int i = 0; i < labels.length; i++) FlSpot(i.toDouble(), balances[i])],
      isCurved: false,
      color: netColor,
      barWidth: 2,
      dotData: FlDotData(show: true),
    );

    Widget bottomTitle(double value, TitleMeta meta) {
      const eps = 0.0001;
      if ((value - value.roundToDouble()).abs() > eps) return const SizedBox.shrink();
      final idx = value.toInt();
      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
      if (idx % labelStep != 0) return const SizedBox.shrink();
      return SideTitleWidget(
        meta: meta,
        space: 4,
        child: Transform.rotate(
          angle: labelAngleDeg * pi / 180.0,
          child: Text(labels[idx], style: const TextStyle(fontSize: 9)),
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: -0.5,
        maxX: labels.length - 0.5,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 1, color: Colors.black12),
        ),
        extraLinesData:
            ExtraLinesData(horizontalLines: [HorizontalLine(y: 0, color: Colors.black26, strokeWidth: 1)]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: bottomReserved,
              interval: 1,
              getTitlesWidget: bottomTitle,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showLeftAxis,
              reservedSize: showLeftAxis ? leftReserved : 0,
              interval: horizontalInterval,
              getTitlesWidget: (v, meta) {
                if (v == 0) {
                  return SideTitleWidget(
                    meta: meta,
                    space: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: const Offset(0, 1),
                        child: const Text(
                          '0',
                          textAlign: TextAlign.right,
                          textHeightBehavior: TextHeightBehavior(
                            applyHeightToFirstAscent: false,
                            applyHeightToLastDescent: false,
                          ),
                          style: TextStyle(fontSize: 11, height: 1.0),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            top: const BorderSide(color: Colors.black12, width: 1),
            right: const BorderSide(color: Colors.black12, width: 1),
            left: BorderSide(
                color: drawLeftBorder ? Colors.black12 : Colors.transparent, width: 1),
            bottom: const BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 24,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return const [];
              final idx = touchedSpots.first.x.round().clamp(0, labels.length - 1);
              final parts = <String>[];
              if (incomes[idx] != 0) parts.add('収入: ${nf.format(incomes[idx])}');
              if (expenses[idx] != 0) parts.add('支出: ${nf.format(-expenses[idx])}');
              parts.add('差分(累計): ${nf.format(balances[idx])}');
              return [
                for (int i = 0; i < touchedSpots.length; i++)
                  i == 0 ? const LineTooltipItem('', TextStyle()) : null
              ];
            },
          ),
        ),
        lineBarsData: [...incomeBars, ...expenseBars, balanceLine],
      ),
    );
  }
}

// ===== Calendar summary card look (compact) =====
class _SummaryTileFrame extends StatelessWidget {
  const _SummaryTileFrame({
    required this.label,
    required this.color,
    required this.icon,
    required this.child,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tileColor = Theme.of(context).cardColor;
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
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
                      label,
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
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: kSummaryAmountLineHeight,
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Simple SliverPersistentHeader delegate =====
class _SimpleHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SimpleHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
  });

  @override
  final double minExtent;
  @override
  final double maxExtent;

  final Widget Function(BuildContext context, double shrinkOffset, bool overlapsContent) builder;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return builder(context, shrinkOffset, overlapsContent);
  }

  @override
  bool shouldRebuild(covariant _SimpleHeaderDelegate oldDelegate) {
    return minExtent != oldDelegate.minExtent ||
        maxExtent != oldDelegate.maxExtent ||
        builder != oldDelegate.builder;
  }
}

// ===== Calendar-like row for analysis table (no delete/tap) =====
class _TxRowAnalysis extends StatelessWidget {
  const _TxRowAnalysis({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;

    final memo = (transaction.memo ?? '').isEmpty ? '－' : transaction.memo!;
    final prefix = isIncome ? '+' : '-';

    return SizedBox(
      height: kTxRowHeight,
      child: Material(
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(isIncome ? Icons.add_circle : Icons.remove_circle, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  transaction.tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Text(
                  memo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$prefix${Formatter.formatAmount(transaction.amount)}円',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Data class =====
class ChartData {
  ChartData(this.date, this.income, this.expense, this.balance);
  final String date; // MM/dd, yy/MM, yyyy
  final int income;
  final int expense;
  final int balance;
}

// ===== Grid interval helper =====
double _niceGridInterval(double maxAbsY) {
  final target = maxAbsY / 5;
  final pow10 = pow(10, (log(target) / log(10)).floor()).toDouble();
  final t = target / pow10;
  double base;
  if (t < 2) {
    base = 2;
  } else if (t < 5) {
    base = 5;
  } else {
    base = 10;
  }
  return base * pow10;
}
