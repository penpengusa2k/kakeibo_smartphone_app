import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';

class TotalAmountDetailPage extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime initialFocusedMonth;
  final String selectedTransactionType;
  final List<String> allTags;
  final List<Color> tagColors;

  const TotalAmountDetailPage({
    super.key,
    required this.transactions,
    required this.initialFocusedMonth,
    required this.selectedTransactionType,
    required this.allTags,
    required this.tagColors,
  });

  @override
  State<TotalAmountDetailPage> createState() => _TotalAmountDetailPageState();
}

class _TotalAmountDetailPageState extends State<TotalAmountDetailPage> {
  DateTime _focusedMonth = DateTime.now();
  late ScrollController _chartScrollController;
  late ScrollController _pageScrollController;
  late List<String> _allMonthKeys;
  static const double _barGroupWidth = 40.0; // 少し太くする
  static const double _barSpace = 60.0;    // 間隔を広げる
  static const double _totalBarWidth = _barGroupWidth + _barSpace;

  @override
  void initState() {
    super.initState();
    _initializeMonths();
    final initialMonthKey = DateFormat('yyyy-MM').format(widget.initialFocusedMonth);
    if (_allMonthKeys.contains(initialMonthKey)) {
      _focusedMonth = widget.initialFocusedMonth;
    } else if (_allMonthKeys.isNotEmpty) {
      _focusedMonth = DateTime.parse('${_allMonthKeys.last}-01');
    }
    _chartScrollController = ScrollController();
    _pageScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocusedMonth());
  }

  void _initializeMonths() {
    List<String> monthKeys = [];
    DateTime now = DateTime.now();
    DateTime minMonth;
    DateTime maxMonth = DateTime(now.year + 1, now.month, 1); // 終了月は1年後

    if (widget.transactions.isEmpty) {
      minMonth = DateTime(now.year, now.month - 7, 1);
    } else {
      DateTime minDate = widget.transactions.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
      DateTime eightMonthsAgo = DateTime(now.year, now.month - 7, 1);
      minMonth = minDate.isBefore(eightMonthsAgo) ? minDate : eightMonthsAgo;
    }

    DateTime currentMonth = DateTime(minMonth.year, minMonth.month, 1);
    // ループの終了条件をmaxMonthにする
    while (currentMonth.isBefore(DateTime(maxMonth.year, maxMonth.month + 1, 1))) {
      monthKeys.add(DateFormat('yyyy-MM').format(currentMonth));
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    _allMonthKeys = monthKeys;
  }

  void _scrollToFocusedMonth() {
    if (!_chartScrollController.hasClients) return;
    final focusedMonthKey = DateFormat('yyyy-MM').format(_focusedMonth);
    final focusedMonthIndex = _allMonthKeys.indexOf(focusedMonthKey);
    if (focusedMonthIndex != -1) {
      final double targetOffset = focusedMonthIndex * _totalBarWidth;
      final double clampedOffset = targetOffset.clamp(
        0.0,
        _chartScrollController.position.maxScrollExtent,
      );
      _chartScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _changeMonth(int months) {
    final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month + months, 1);
    final newMonthKey = DateFormat('yyyy-MM').format(newMonth);
    if (_allMonthKeys.contains(newMonthKey)) {
      setState(() => _focusedMonth = newMonth);
      _scrollToFocusedMonth();
      _scrollToTransactionList();
    }
  }

  void _scrollToTransactionList() {
    _pageScrollController.animateTo(
      _pageScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMonthTransactions = widget.transactions.where((t) =>
        t.date.year == _focusedMonth.year &&
        t.date.month == _focusedMonth.month).toList();

    // 月ごと、タグごとのデータを集計
    final Map<String, Map<String, int>> monthlyTagData = {
      for (var monthKey in _allMonthKeys) monthKey: {},
    };
    for (var t in widget.transactions) {
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      if (monthlyTagData.containsKey(monthKey)) {
        monthlyTagData[monthKey]![t.tag] = (monthlyTagData[monthKey]![t.tag] ?? 0) + t.amount;
      }
    }

    final List<String> sortedMonthKeys = monthlyTagData.keys.toList()..sort();
    double maxY = monthlyTagData.values.map((e) => e.values.fold(0, (a, b) => a + b)).fold(0, (prev, val) => val > prev ? val.toDouble() : prev.toDouble());
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY == 0) maxY = 1000;

    final List<BarChartGroupData> monthlyBarGroups = [];
    for (int i = 0; i < sortedMonthKeys.length; i++) {
      final monthKey = sortedMonthKeys[i];
      final tagDataForMonth = monthlyTagData[monthKey]!;
      final totalForMonth = tagDataForMonth.values.fold(0, (a, b) => a + b);

      final List<BarChartRodStackItem> rodStackItems = [];
      double currentFromY = 0;
      for (var tag in widget.allTags) {
        if (tagDataForMonth.containsKey(tag)) {
          final amount = tagDataForMonth[tag]!;
          final toY = currentFromY + amount;
          final colorIndex = widget.allTags.indexOf(tag) % widget.tagColors.length;
          rodStackItems.add(
            BarChartRodStackItem(currentFromY, toY, widget.tagColors[colorIndex]),
          );
          currentFromY = toY;
        }
      }

      monthlyBarGroups.add(
        BarChartGroupData(
          x: i,
          showingTooltipIndicators: totalForMonth > 0 ? [0] : [],
          barRods: [
            BarChartRodData(
              toY: totalForMonth.toDouble(),
              rodStackItems: rodStackItems,
              width: _barGroupWidth,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
    }

    final chartWidth = sortedMonthKeys.length * _totalBarWidth;
    
    final now = DateTime.now();
    final oneYearLater = DateTime(now.year + 1, now.month, 1);
    final isNextDisabled = _focusedMonth.year == oneYearLater.year && _focusedMonth.month == oneYearLater.month;

    return Scaffold(
      appBar: AppBar(
        title: Text('月別合計推移'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _pageScrollController,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: SingleChildScrollView(
                          controller: _chartScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: BarChart(
                              BarChartData(
                                maxY: maxY,
                                barGroups: monthlyBarGroups,
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    tooltipBgColor: Colors.transparent,
                                    tooltipPadding: const EdgeInsets.only(bottom: 4),
                                    tooltipMargin: 16,
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final monthKey = sortedMonthKeys[group.x];
                                      final tagDataForMonth = monthlyTagData[monthKey]!;
                                      final totalForMonth = tagDataForMonth.values.fold(0, (a, b) => a + b);
                                      if (totalForMonth == 0) return null;

                                      return BarTooltipItem(
                                        '${Formatter.formatAmount(totalForMonth)}円',
                                        const TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                  touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                                    if (response?.spot != null && event.isInterestedForInteractions) {
                                      final touchedBarGroupIndex = response!.spot!.touchedBarGroupIndex;
                                      if (touchedBarGroupIndex < sortedMonthKeys.length) {
                                        final selectedMonthKey = sortedMonthKeys[touchedBarGroupIndex];
                                        final selectedMonth = DateTime.parse('$selectedMonthKey-01');
                                        if (selectedMonth != _focusedMonth) {
                                          setState(() {
                                            _focusedMonth = selectedMonth;
                                          });
                                          _scrollToFocusedMonth();
                                          _scrollToTransactionList();
                                        }
                                      }
                                    }
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        if (value.toInt() < sortedMonthKeys.length) {
                                          final monthKey = sortedMonthKeys[value.toInt()];
                                          final isFocused = DateFormat('yyyy-MM').format(_focusedMonth) == monthKey;
                                          return Text(
                                            DateFormat('yy/MM').format(DateTime.parse('$monthKey-01')),
                                            style: TextStyle(
                                              fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                                              color: isFocused ? Theme.of(context).primaryColor : Colors.black,
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
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
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(DateFormat('yyyy年MM月').format(_focusedMonth), style: Theme.of(context).textTheme.titleLarge),
                  isNextDisabled
                    ? const SizedBox(width: 48.0)
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _changeMonth(1),
                      ),
                ],
              ),
              const SizedBox(height: 16.0),
              Text('${DateFormat('yyyy年MM月').format(_focusedMonth)} の内訳', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8.0),
              Builder(
                builder: (context) {
                  final focusedMonthKey = DateFormat('yyyy-MM').format(_focusedMonth);
                  final tagDataForMonth = monthlyTagData[focusedMonthKey] ?? {};
                  final totalForMonth = tagDataForMonth.values.fold(0, (prev, amount) => prev + amount);
                  final sortedTags = tagDataForMonth.keys.toList()..sort((a, b) => tagDataForMonth[b]!.compareTo(tagDataForMonth[a]!));

                  if (tagDataForMonth.isEmpty) {
                    return const Center(child: Text('この月の取引はありません。'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedTags.length,
                    itemBuilder: (context, index) {
                      final tag = sortedTags[index];
                      final amount = tagDataForMonth[tag]!;
                      final percentage = totalForMonth > 0 ? (amount / totalForMonth * 100) : 0.0;
                      String percentageText;
                      if (percentage > 0 && percentage < 0.1) {
                        percentageText = '<0.1';
                      } else {
                        percentageText = percentage.toStringAsFixed(1);
                      }
                      final colorIndex = widget.allTags.indexOf(tag) % widget.tagColors.length;
                      final color = widget.tagColors[colorIndex];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: Container(
                            width: 60,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$percentageText%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(tag),
                          trailing: Text(
                            '${Formatter.formatAmount(amount)}円',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
