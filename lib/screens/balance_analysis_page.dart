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
          _endDate   = DateTime(now.year, now.month + 1, 0); // 月末
          break;
        case Period.year:
          _startDate = DateTime(now.year - 2, 1, 1);
          _endDate   = DateTime(now.year, 12, 31);           // 年末
          break;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (!mounted) return;
    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
      });
    }
  }

  Future<void> _selectPeriod(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _startDate.year;
    int selectedMonth = _startDate.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('期間を選択', textAlign: TextAlign.center),
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
              onPressed: () => Navigator.of(context).pop(DateTime.now()),
              child: const Text('今月へ戻る'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                DateTime selectedDate;
                if (_selectedPeriod == Period.year) {
                  selectedDate = DateTime(selectedYear, 1, 1);
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
      setState(() {
        if (_selectedPeriod == Period.year) {
          _startDate = DateTime(result.year, 1, 1);
          _endDate   = DateTime(result.year, 12, 31);
        } else {
          _startDate = DateTime(result.year, result.month, 1);
          _endDate   = DateTime(result.year, result.month + 1, 0);
        }
      });
    }
  }

  List<ChartData> _getChartData(List<Transaction> transactions) {
    final Map<String, Map<String, int>> aggregatedData = {};

    final filtered = transactions.where((t) {
      return t.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
             t.date.isBefore(_endDate.add(const Duration(days: 1)));
    }).toList();

    for (var t in filtered) {
      String keyDate;
      switch (_selectedPeriod) {
        case Period.day:
          keyDate = DateFormat('MM/dd').format(t.date);
          break;
        case Period.month:
          keyDate = DateFormat('yy/MM').format(t.date);
          break;
        case Period.year:
          keyDate = DateFormat('yyyy').format(t.date);
          break;
      }
      aggregatedData.putIfAbsent(keyDate, () => {'income': 0, 'expense': 0});
      if (t.type == 'income') {
        aggregatedData[keyDate]!['income'] =
            (aggregatedData[keyDate]!['income'] ?? 0) + t.amount;
      } else {
        aggregatedData[keyDate]!['expense'] =
            (aggregatedData[keyDate]!['expense'] ?? 0) + t.amount;
      }
    }

    // 期間内のラベル（Xは index）
    final List<String> dateKeys = [];
    DateTime cur = _startDate;
    while (cur.isBefore(_endDate) || cur.isAtSameMomentAs(_endDate)) {
      switch (_selectedPeriod) {
        case Period.day:
          dateKeys.add(DateFormat('MM/dd').format(cur));
          cur = cur.add(const Duration(days: 1));
          break;
        case Period.month:
          dateKeys.add(DateFormat('yy/MM').format(cur));
          cur = DateTime(cur.year, cur.month + 1, 1);
          break;
        case Period.year:
          dateKeys.add(DateFormat('yyyy').format(cur));
          cur = DateTime(cur.year + 1, 1, 1);
          break;
      }
    }

    return dateKeys.map((key) {
      final income  = aggregatedData[key]?['income']  ?? 0;
      final expense = aggregatedData[key]?['expense'] ?? 0;
      final balance = income - expense;
      return ChartData(key, income, expense, balance);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context.select<TransactionViewModel, List<Transaction>>(
      (vm) => vm.transactions,
    );
    final data = _getChartData(transactions);

    String dateRangeText;
    if (_selectedPeriod == Period.day) {
      dateRangeText =
          '${DateFormat('yyyy年MM月dd日').format(_startDate)} - ${DateFormat('yyyy年MM月dd日').format(_endDate)}';
    } else if (_selectedPeriod == Period.month) {
      dateRangeText =
          '${DateFormat('yyyy年MM月').format(_startDate)} - ${DateFormat('yyyy年MM月').format(_endDate)}';
    } else {
      dateRangeText =
          '${DateFormat('yyyy年').format(_startDate)} - ${DateFormat('yyyy年').format(_endDate)}';
    }

    // Y軸レンジ（±対称）
    double maxAbsValue = 0;
    for (final d in data) {
      maxAbsValue = max(maxAbsValue, d.income.abs().toDouble());
      maxAbsValue = max(maxAbsValue, d.expense.abs().toDouble());
      maxAbsValue = max(maxAbsValue, d.balance.abs().toDouble());
    }
    maxAbsValue = (maxAbsValue == 0 ? 1000 : maxAbsValue * 1.1);

    // ラベル回転・間引き
    double labelAngleDeg = 0;
    int labelStep = 1;
    if (_selectedPeriod == Period.day) {
      labelAngleDeg = -45;
      if (data.length > 10) labelStep = 2;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('収支分析')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Center(
                child: ToggleButtons(
                  isSelected: Period.values.map((p) => _selectedPeriod == p).toList(),
                  onPressed: (int index) {
                    setState(() {
                      _selectedPeriod = Period.values[index];
                      _updateDateRange();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('日')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('月')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('年')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (_selectedPeriod == Period.day) {
                    _selectDate(context);
                  } else {
                    _selectPeriod(context);
                  }
                },
                child: Text(
                  dateRangeText,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              // 凡例
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Colors.green, label: '収入'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.red, label: '支出'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.blue, label: '収支'),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: data.isEmpty
                        ? const Center(child: Text('データがありません'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // 1点あたりの横幅（お好みで調整）
                              final step = _selectedPeriod == Period.day
                                  ? 56.0
                                  : (_selectedPeriod == Period.month ? 72.0 : 100.0);

                              final contentWidth =
                                  max(constraints.maxWidth, data.length * step);

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: SizedBox(
                                  width: contentWidth,
                                  child: _UnifiedLineChart(
                                    labels: data.map((e) => e.date).toList(),
                                    incomes:
                                        data.map((e) => e.income.toDouble()).toList(),
                                    expenses:
                                        data.map((e) => (-e.expense).toDouble()).toList(),
                                    balances:
                                        data.map((e) => e.balance.toDouble()).toList(),
                                    maxAbsY: maxAbsValue,
                                    labelAngleDeg: labelAngleDeg,
                                    labelStep: labelStep,
                                  ),
                                ),
                              );
                            },
                          ),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
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
  });

  final List<String> labels;
  final List<double> incomes;   // 正
  final List<double> expenses;  // 既に負で渡す
  final List<double> balances;
  final double maxAbsY;
  final double labelAngleDeg;
  final int labelStep;

  static const double _leftReserved = 44;
  double get _bottomReserved => labelAngleDeg == 0 ? 24 : 40;

  @override
  Widget build(BuildContext context) {
    // 棒（縦線分）
    final incomeBars = <LineChartBarData>[
      for (int i = 0; i < labels.length; i++)
        if (incomes[i] != 0)
          LineChartBarData(
            spots: [FlSpot(i.toDouble(), 0), FlSpot(i.toDouble(), incomes[i])],
            isCurved: false,
            color: Colors.green,
            barWidth: 12,
            dotData: FlDotData(show: false),
            isStrokeCapRound: false,
          ),
    ];
    final expenseBars = <LineChartBarData>[
      for (int i = 0; i < labels.length; i++)
        if (expenses[i] != 0)
          LineChartBarData(
            spots: [FlSpot(i.toDouble(), 0), FlSpot(i.toDouble(), expenses[i])],
            isCurved: false,
            color: Colors.red,
            barWidth: 12,
            dotData: FlDotData(show: false),
            isStrokeCapRound: false,
          ),
    ];

    // 折れ線
    final balanceLine = LineChartBarData(
      spots: [for (int i = 0; i < labels.length; i++) FlSpot(i.toDouble(), balances[i])],
      isCurved: false,
      color: Colors.blue,
      barWidth: 2,
      dotData: FlDotData(show: true),
    );

    // X軸タイトル（整数目盛のみ + 間引き）
    Widget bottomTitle(double value, TitleMeta meta) {
      const eps = 0.0001;
      if ((value - value.roundToDouble()).abs() > eps) {
        return const SizedBox.shrink();
      }
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
        minX: 0,
        maxX: labels.length - 1,
        minY: -maxAbsY,
        maxY: maxAbsY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(strokeWidth: 0.5, color: Colors.black12),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            top: BorderSide(color: Colors.black12, width: 1),
            right: BorderSide(color: Colors.black12, width: 1),
            left: BorderSide(color: Colors.black12, width: 1),
            bottom: BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _bottomReserved,
              interval: 1, // ここが効く：整数インデックスのみに固定
              getTitlesWidget: bottomTitle,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _leftReserved,
              getTitlesWidget: (v, _) =>
                  Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
        lineTouchData: LineTouchData(enabled: false),
        lineBarsData: [
          ...incomeBars,
          ...expenseBars,
          balanceLine,
        ],
      ),
    );
  }
}

class ChartData {
  ChartData(this.date, this.income, this.expense, this.balance);
  final String date;
  final int income;
  final int expense;
  final int balance;
}
