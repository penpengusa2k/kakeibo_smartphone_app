// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';

class TagDetailPage extends StatefulWidget {
  final String tagName;
  final List<Transaction> transactions;
  final DateTime initialFocusedMonth;
  final String selectedTransactionType;
  final Color tagColor;

  const TagDetailPage({
    super.key,
    required this.tagName,
    required this.transactions,
    required this.initialFocusedMonth,
    required this.selectedTransactionType,
    required this.tagColor,
  });

  @override
  State<TagDetailPage> createState() => _TagDetailPageState();
}

class _TagDetailPageState extends State<TagDetailPage> {
  DateTime _focusedMonth = DateTime.now();
  late ScrollController _chartScrollController;
  late ScrollController _pageScrollController;
  late List<String> _allMonthKeys;
  static const double _barGroupWidth = 20.0;
  static const double _barSpace = 40.0;
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

    final Map<String, int> monthlyTagData = {
      for (var key in _allMonthKeys) key: 0,
    };
    for (var t in widget.transactions) {
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      if (monthlyTagData.containsKey(monthKey)) {
        monthlyTagData[monthKey] = monthlyTagData[monthKey]! + t.amount;
      }
    }

    final List<String> sortedMonthKeys = monthlyTagData.keys.toList()..sort();
    double maxY = monthlyTagData.values.fold(0, (prev, val) => val > prev ? val.toDouble() : prev.toDouble());
    maxY = (maxY * 1.2).ceilToDouble();
    
    if (maxY == 0) {
      maxY = 1000;
    }
    
    final List<BarChartGroupData> monthlyBarGroups = [
      for (int i = 0; i < sortedMonthKeys.length; i++)
        BarChartGroupData(
          x: i,
          showingTooltipIndicators: monthlyTagData[sortedMonthKeys[i]]! > 0 ? [0] : [],
          barRods: [
            BarChartRodData(
              toY: monthlyTagData[sortedMonthKeys[i]]!.toDouble(),
              color: widget.tagColor,
              width: _barGroupWidth,
              borderRadius: BorderRadius.zero,
            ),
          ],
        )
    ];

    final chartWidth = sortedMonthKeys.length * _totalBarWidth;
    
    final now = DateTime.now();
    final oneYearLater = DateTime(now.year + 1, now.month, 1);
    final isNextDisabled = _focusedMonth.year == oneYearLater.year && _focusedMonth.month == oneYearLater.month;

    return Scaffold(
      appBar: AppBar(
        // AppBarのタイトルを「月別推移」に変更
        title: Text('${widget.tagName} の月別推移'),
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
                      // グラフ上部のタイトルを削除
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
                                      final value = rod.toY.toInt();
                                      if (value == 0) return null;
                                      return BarTooltipItem(
                                        '${Formatter.formatAmount(value)}円',
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
              Text('${DateFormat('yyyy年MM月').format(_focusedMonth)} の取引', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8.0),
              currentMonthTransactions.isEmpty
                  ? const Center(child: Text('この月の取引はありません。'))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentMonthTransactions.length,
                      itemBuilder: (context, index) {
                        final t = currentMonthTransactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            title: Text(
                              '${DateFormat('MM/dd').format(t.date)}: ${Formatter.formatAmount(t.amount)}円',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: t.type == 'income' ? Colors.green : Colors.red,
                              ),
                            ),
                            subtitle: Text(t.memo ?? 'メモなし'),
                          ),
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
