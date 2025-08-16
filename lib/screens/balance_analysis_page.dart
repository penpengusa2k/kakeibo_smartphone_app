import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';

enum Period { day, month, year }

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
          _startDate = DateTime(now.year, now.month, now.day)
              .subtract(const Duration(days: 7));
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
            if (selectedDay > daysInMonth) {
              selectedDay = daysInMonth;
            }

            return AlertDialog(
              title: Text(isStartDate ? '開始日を選択' : '終了日を選択', textAlign: TextAlign.center),
              content: SizedBox(
                width: 300,
                height: 200,
                child: Row(
                  children: [
                    // 年ピッカー
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedYear - 2000),
                        itemExtent: 40.0,
                        onSelectedItemChanged: (int index) {
                          setState(() {
                            selectedYear = 2000 + index;
                          });
                        },
                        children: List<Widget>.generate(
                          now.year - 2000 + 2,
                          (int index) => Center(child: Text('${2000 + index}年')),
                        ),
                      ),
                    ),
                    // 月ピッカー
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedMonth - 1),
                        itemExtent: 40.0,
                        onSelectedItemChanged: (int index) {
                          setState(() {
                            selectedMonth = index + 1;
                          });
                        },
                        children: List<Widget>.generate(
                          12,
                          (int index) => Center(child: Text('${index + 1}月')),
                        ),
                      ),
                    ),
                    // 日ピッカー
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(initialItem: selectedDay - 1),
                        itemExtent: 40.0,
                        onSelectedItemChanged: (int index) {
                          selectedDay = index + 1;
                        },
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(DateTime(selectedYear, selectedMonth, selectedDay));
                  },
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('開始日は終了日より前に設定してください。')));
        return;
      }
      if (!isStartDate && pickedDate.isBefore(_startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('終了日は開始日より後に設定してください。')));
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
                    onSelectedItemChanged: (int index) {
                      selectedYear = 2000 + index;
                    },
                    children: List<Widget>.generate(
                      now.year - 2000 + 2,
                      (int index) => Center(
                        child: Text('${2000 + index}年',
                            style: const TextStyle(fontSize: 20)),
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
                      onSelectedItemChanged: (int index) {
                        selectedMonth = index + 1;
                      },
                      children: List<Widget>.generate(
                        12,
                        (int index) => Center(
                          child: Text('${index + 1}月',
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('開始期間は終了期間より前に設定してください。')));
        return;
      }
      if (!isStartDate && newDate.isBefore(_startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('終了期間は開始期間より後に設定してください。')));
        return;
      }

      setState(() {
        if (isStartDate) {
          if (_selectedPeriod == Period.year) {
            _startDate = DateTime(newDate.year, 1, 1);
          } else {
            _startDate = DateTime(newDate.year, newDate.month, 1);
          }
        } else { // isEndDate
          if (_selectedPeriod == Period.year) {
            _endDate = DateTime(newDate.year, 12, 31);
          } else {
            _endDate = DateTime(newDate.year, newDate.month + 1, 0);
          }
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

    return keys.map((k) {
      final income = agg[k]?['income'] ?? 0;
      final expense = agg[k]?['expense'] ?? 0;
      final balance = income - expense;
      return ChartData(k, income, expense, balance);
    }).toList();
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 36,
            child: Center(child: Text(valueText, style: const TextStyle(fontSize: 16, color: Colors.black87))),
          ),
        ),
        Positioned(
          top: -8,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final txs = context.select<TransactionViewModel, List<Transaction>>((vm) => vm.transactions);
    final data = _getChartData(txs);
    final nf = NumberFormat('#,###');

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

    final periodToggle = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        fixedSize: const Size(90, 36),
      ),
      icon: const Icon(Icons.sync, size: 18),
      label: Text(periodText),
      onPressed: () {
        setState(() {
          final currentIndex = Period.values.indexOf(_selectedPeriod);
          final nextIndex = (currentIndex + 1) % Period.values.length;
          _selectedPeriod = Period.values[nextIndex];
          _updateDateRange();
        });
      },
    );

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

    final datePickerWidget = Row(
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
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('～', style: TextStyle(fontSize: 16, color: Colors.black54)),
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
    );

    final inRange = txs.where((t) => !t.date.isBefore(_startDate) && !t.date.isAfter(_endDate)).toList();
    final expensesList = inRange.where((t) => t.type == 'expense').toList()..sort((a, b) => a.date.compareTo(b.date));
    final incomesList  = inRange.where((t) => t.type == 'income').toList() ..sort((a, b) => a.date.compareTo(b.date));

    final totalExpense = expensesList.fold<int>(0, (s, t) => s + t.amount);
    final totalIncome  = incomesList.fold<int>(0, (s, t) => s + t.amount);
    final totalNet     = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('収支分析'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: periodToggle,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: datePickerWidget,
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: data.isEmpty
                        ? const Center(child: Text('データがありません'))
                        : _StickyYAxisScrollableChart(
                            data: data,
                            period: _selectedPeriod,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Colors.green, label: '収入'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.red, label: '支出'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.blue, label: '差分(累計)'),
                ],
              ),

              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      _TotalCell(label: '収入', value: '${nf.format(totalIncome)} 円', color: Colors.green),
                      const VerticalDivider(width: 24, thickness: 1),
                      _TotalCell(label: '支出', value: '${nf.format(totalExpense)} 円', color: Colors.red),
                      const VerticalDivider(width: 24, thickness: 1),
                      _TotalCell(label: '差分(累計)', value: '${nf.format(totalNet)} 円', color: Colors.blue),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('この期間の明細', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),

              _SectionHeader(title: '支出', color: Colors.red),
              const SizedBox(height: 8),
              if (expensesList.isEmpty)
                const _EmptyNote(text: '支出の記録はありません')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expensesList.length,
                  itemBuilder: (context, i) {
                    final t = expensesList[i];
                    return _TxCard(
                      transaction: t,
                      tag: _safeTag(t),
                    );
                  },
                ),

              const SizedBox(height: 16),

              _SectionHeader(title: '収入', color: Colors.green),
              const SizedBox(height: 8),
              if (incomesList.isEmpty)
                const _EmptyNote(text: '収入の記録はありません')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: incomesList.length,
                  itemBuilder: (context, i) {
                    final t = incomesList[i];
                    return _TxCard(
                      transaction: t,
                      tag: _safeTag(t),
                    );
                  },
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _safeTag(Transaction t) {
    try {
      final dynamicTag = (t as dynamic).tag;
      if (dynamicTag is String && dynamicTag.isNotEmpty) return dynamicTag;
    } catch (_) {}
    return '未分類';
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 固定Y軸＋横スクロール本体（折れ線は累計推移）
// ─────────────────────────────────────────────────────────────
class _StickyYAxisScrollableChart extends StatelessWidget {
  const _StickyYAxisScrollableChart({
    required this.data,
    required this.period,
  });

  final List<ChartData> data;
  final Period period;

  // 左側の固定Y軸の幅を最小限に
  static const double _leftReserved = 14;

  double _bottomReserved(double labelAngleDeg) => labelAngleDeg == 0 ? 24 : 40;

  @override
  Widget build(BuildContext context) {
    final labels = data.map((e) => e.date).toList();
    final incomes = data.map((e) => e.income.toDouble()).toList();
    final expenses = data.map((e) => (-e.expense).toDouble()).toList(); // 棒は負で下向き

    // 累計折れ線
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
    final step = period == Period.day ? 56.0 : (period == Period.month ? 72.0 : 100.0);

    return LayoutBuilder(builder: (context, constraints) {
      final plotWidth = max(constraints.maxWidth - _leftReserved, step * labels.length);

      // 左：Y軸側チャート
      final axisChart = LineChart(
        LineChartData(
          minX: 0, maxX: 1,
          minY: -maxAbsY,
          maxY: maxAbsY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 1, color: Colors.black12),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: Colors.black26, strokeWidth: 1),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false, reservedSize: _bottomReserved(labelAngle)),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: _leftReserved,
                interval: interval,
                getTitlesWidget: (v, meta) {
                  if (v == 0) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Transform.translate(
                          offset: const Offset(0, -8), // 0線と視覚的に揃うよう微調整
                          child: const Text(
                            '0',
                            textAlign: TextAlign.right,
                            textHeightBehavior: TextHeightBehavior(
                              applyHeightToFirstAscent: false,
                              applyHeightToLastDescent: false,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.0,
                            ),
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

      // 右：グラフ本体（スクロール）
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

// 1つのLineChartで 棒(縦線) + 折れ線(累計) を描画（ツールチップ対応）
class _UnifiedLineChart extends StatelessWidget {
  const _UnifiedLineChart({
    required this.labels,
    required this.incomes,
    required this.expenses, // 負で渡す
    required this.balances, // 累計
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

    // 棒（縦線分）
    final incomeBars = <LineChartBarData>[];
    final expenseBars = <LineChartBarData>[];
    for (int i = 0; i < labels.length; i++) {
      if (incomes[i] != 0) {
        incomeBars.add(
          LineChartBarData(
            spots: [FlSpot(i.toDouble(), 0), FlSpot(i.toDouble(), incomes[i])],
            isCurved: false,
            color: Colors.green,
            barWidth: 12,
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
            barWidth: 12,
            dotData: FlDotData(show: false),
            isStrokeCapRound: false,
          ),
        );
      }
    }

    // 折れ線（差分(累計)）
    final balanceLine = LineChartBarData(
      spots: [for (int i = 0; i < labels.length; i++) FlSpot(i.toDouble(), balances[i])],
      isCurved: false,
      color: netColor,
      barWidth: 2,
      dotData: FlDotData(show: true),
    );

    // X軸タイトル（整数のみ + 間引き）
    Widget bottomTitle(double value, TitleMeta meta) {
      const eps = 0.0001;
      if ((value - value.roundToDouble()).abs() > eps) return const SizedBox.shrink();
      final idx = value.toInt();
      if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
      if (idx % labelStep != 0) return const SizedBox.shrink();
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 6,
        child: Transform.rotate(
          angle: labelAngleDeg * pi / 180.0,
          child: Text(labels[idx], style: const TextStyle(fontSize: 10)),
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
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(y: 0, color: Colors.black26, strokeWidth: 1),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    axisSide: meta.axisSide,
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
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.0,
                          ),
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
            left: BorderSide(color: drawLeftBorder ? Colors.black12 : Colors.transparent, width: 1),
            bottom: const BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        // ツールチップ（差分まとめ）
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 24,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipBgColor: Colors.black87,
            getTooltipItems: (touchedSpots) {
              if (touchedSpots.isEmpty) return const [];
              final idx = touchedSpots.first.x.round().clamp(0, labels.length - 1);
              final parts = <String>[];
              if (incomes[idx] != 0) parts.add('収入: ${nf.format(incomes[idx])}');
              if (expenses[idx] != 0) parts.add('支出: ${nf.format(-expenses[idx])}');
              parts.add('差分(累計): ${nf.format(balances[idx])}');
              final text = '${labels[idx]}\n${parts.join('\n')}';
              return [for (int i = 0; i < touchedSpots.length; i++) i == 0 ? LineTooltipItem(text, const TextStyle(color: Colors.white)) : null];
            },
          ),
        ),
        lineBarsData: [
          ...incomeBars,
          ...expenseBars,
          balanceLine,
        ],
      ),
    );
  }
}

// ── 明細UI ─────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(text),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.transaction,
    required this.tag,
  });

  final Transaction transaction;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,###');
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;
    final amountText = '${isIncome ? '+' : '-'}${nf.format(transaction.amount)} 円';
    final d = DateFormat('yyyy/MM/dd').format(transaction.date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              isIncome ? Icons.add_circle : Icons.remove_circle,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tag, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(d, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amountText,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// サマリー用セル
class _TotalCell extends StatelessWidget {
  const _TotalCell({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ── 集計用データクラス ─────────────────
class ChartData {
  ChartData(this.date, this.income, this.expense, this.balance);
  final String date;  // ラベル（MM/dd, yy/MM, yyyy）
  final int income;   // 正
  final int expense;  // 正（集計時に負に変換）
  final int balance;  // 単月/日/年の差分
}

/// 左右のチャートで共有する“きれいな”水平グリッド間隔を作る
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