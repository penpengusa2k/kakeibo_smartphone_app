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
          _startDate =
              DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
          _endDate = DateTime(now.year, now.month, now.day);
          break;
        case Period.month:
          _startDate = DateTime(now.year, now.month - 6, 1);
          _endDate = DateTime(now.year, now.month + 1, 0); // 月末
          break;
        case Period.year:
          _startDate = DateTime(now.year - 2, 1, 1);
          _endDate = DateTime(now.year, 12, 31); // 年末
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
          _endDate = DateTime(result.year, 12, 31);
        } else {
          _startDate = DateTime(result.year, result.month, 1);
          _endDate = DateTime(result.year, result.month + 1, 0);
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

  @override
  Widget build(BuildContext context) {
    final txs = context.select<TransactionViewModel, List<Transaction>>((vm) => vm.transactions);
    final data = _getChartData(txs);

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

    // 表示は各チャート側で計算するのでここでは触らない

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
                  onPressed: (i) {
                    setState(() {
                      _selectedPeriod = Period.values[i];
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Colors.green, label: '収入'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.red, label: '支出'),
                  SizedBox(width: 12),
                  _LegendDot(color: Colors.blue, label: '収支(累計)'),
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
                        : _StickyYAxisScrollableChart(
                            data: data,
                            period: _selectedPeriod,
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
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// 横スクロール本体 + 固定Y軸（折れ線は累計推移）
// ───────────────────────────────────────────────────────────────────
class _StickyYAxisScrollableChart extends StatelessWidget {
  const _StickyYAxisScrollableChart({
    required this.data,
    required this.period,
  });

  final List<ChartData> data;
  final Period period;

  static const double _leftReserved = 44;

  double _bottomReserved(double labelAngleDeg) =>
      labelAngleDeg == 0 ? 24 : 40;

  @override
  Widget build(BuildContext context) {
    final labels = data.map((e) => e.date).toList();
    final incomes = data.map((e) => e.income.toDouble()).toList();
    final expenses = data.map((e) => (-e.expense).toDouble()).toList(); // 負で持つ

    // 折れ線は累計推移に変更
    final cumulative = <double>[];
    double run = 0;
    for (int i = 0; i < labels.length; i++) {
      run += incomes[i] + expenses[i]; // 収入 + (負の)支出
      cumulative.add(run);
    }

    // ラベル角度・間引き
    double labelAngle = 0;
    int labelStep = 1;
    if (period == Period.day) {
      labelAngle = -45;
      if (labels.length > 10) labelStep = 2;
    }

    // Yレンジは 棒(収入/支出) と 累計 の両方を含めて決定
    double maxAbsY = 0;
    for (int i = 0; i < labels.length; i++) {
      maxAbsY = max(maxAbsY, incomes[i].abs());
      maxAbsY = max(maxAbsY, expenses[i].abs());
      maxAbsY = max(maxAbsY, cumulative[i].abs());
    }
    if (maxAbsY == 0) maxAbsY = 1000;
    maxAbsY *= 1.1;

    // 1点あたりの横幅（期間に応じて広め）
    final step = period == Period.day ? 56.0 : (period == Period.month ? 72.0 : 100.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = max(constraints.maxWidth - _leftReserved, step * labels.length);

        // 左：固定Y軸（横グリッド＆左目盛だけ）
        final axisChart = LineChart(
          LineChartData(
            minX: 0,
            maxX: 1,
            minY: -maxAbsY,
            maxY: maxAbsY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 0.5, color: Colors.black12),
            ),
            titlesData: FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: false,
                  reservedSize: _bottomReserved(labelAngle),
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
            lineTouchData: LineTouchData(enabled: false),
          ),
        );

        // 右：スクロールする本体（左目盛なし）
        final scrollChart = _UnifiedLineChart(
          labels: labels,
          incomes: incomes,
          expenses: expenses,
          balances: cumulative,           // 累計
          maxAbsY: maxAbsY,
          labelAngleDeg: labelAngle,
          labelStep: labelStep,
          showLeftAxis: false,
          leftReserved: _leftReserved,
          bottomReserved: _bottomReserved(labelAngle),
          drawLeftBorder: false,
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
      },
    );
  }
}

// 1つのLineChartで 棒(縦線) + 折れ線(累計) を描画（ツールチップ対応）
class _UnifiedLineChart extends StatelessWidget {
  const _UnifiedLineChart({
    required this.labels,
    required this.incomes,
    required this.expenses, // 既に負で渡す
    required this.balances, // ここは累計に変更されて渡ってくる
    required this.maxAbsY,
    required this.labelAngleDeg,
    required this.labelStep,
    this.showLeftAxis = true,
    this.leftReserved = 44,
    this.bottomReserved = 24,
    this.drawLeftBorder = true,
  });

  final List<String> labels;
  final List<double> incomes;
  final List<double> expenses; // negative
  final List<double> balances; // cumulative
  final double maxAbsY;
  final double labelAngleDeg;
  final int labelStep;

  final bool showLeftAxis;
  final double leftReserved;
  final double bottomReserved;
  final bool drawLeftBorder;

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

    final nf = NumberFormat('#,###');

    return LineChart(
      LineChartData(
        // 左右端が切れないよう 0.5 ずつ広げる
        minX: -0.5,
        maxX: labels.length - 0.5,
        minY: -maxAbsY,
        maxY: maxAbsY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(strokeWidth: 0.5, color: Colors.black12),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: bottomReserved,
              interval: 1, // 整数インデックスだけ
              getTitlesWidget: bottomTitle,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showLeftAxis,
              reservedSize: showLeftAxis ? leftReserved : 0,
              getTitlesWidget: (v, _) =>
                  Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            top: const BorderSide(color: Colors.black12, width: 1),
            right: const BorderSide(color: Colors.black12, width: 1),
            left: BorderSide(
              color: drawLeftBorder ? Colors.black12 : Colors.transparent,
              width: 1,
            ),
            bottom: const BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        // ツールチップ（同じxの 収入/支出/累計 を1つにまとめて表示）
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
              parts.add('収支(累計): ${nf.format(balances[idx])}');
              final text = '${labels[idx]}\n${parts.join('\n')}';
              final item = LineTooltipItem(text, const TextStyle(color: Colors.white));
              return [for (int i = 0; i < touchedSpots.length; i++) i == 0 ? item : null];
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

class ChartData {
  ChartData(this.date, this.income, this.expense, this.balance);
  final String date;   // ラベル（MM/dd, yy/MM, yyyy）
  final int income;    // 正
  final int expense;   // 正（集計時に負に変換）
  final int balance;   // 単月/日/年の差分（表示では使わないが残しておく）
}
