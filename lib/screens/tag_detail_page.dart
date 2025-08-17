// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';

class TagDetailPage extends StatefulWidget {
  final String tagName;
  final List<Transaction> transactions; // ← このタグだけの取引が渡ってくる想定
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

  // 表示対象の月キー（yyyy-MM）
  late List<String> _allMonthKeys;

  // グラフの見た目
  static const double _barGroupWidth = 20.0;
  static const double _barSpace = 40.0;
  static const double _totalBarWidth = _barGroupWidth + _barSpace;

  @override
  void initState() {
    super.initState();
    _initializeMonths();

    final initialKey = DateFormat('yyyy-MM').format(widget.initialFocusedMonth);
    if (_allMonthKeys.contains(initialKey)) {
      _focusedMonth = widget.initialFocusedMonth;
    } else if (_allMonthKeys.isNotEmpty) {
      _focusedMonth = DateTime.parse('${_allMonthKeys.last}-01');
    }

    _chartScrollController = ScrollController();
    _pageScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocusedMonth());
  }

  void _initializeMonths() {
    final now = DateTime.now();

    // 開始月：最古の取引月 or 8ヶ月前 のうち古い方
    DateTime minMonth;
    if (widget.transactions.isEmpty) {
      minMonth = DateTime(now.year, now.month - 7, 1);
    } else {
      final minDate = widget.transactions
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final eightMonthsAgo = DateTime(now.year, now.month - 7, 1);
      minMonth = minDate.isBefore(eightMonthsAgo)
          ? DateTime(minDate.year, minDate.month, 1)
          : eightMonthsAgo;
    }

    // 終了月：1年後の同月
    final maxMonth = DateTime(now.year + 1, now.month, 1);

    final keys = <String>[];
    var cur = DateTime(minMonth.year, minMonth.month, 1);
    while (cur.isBefore(DateTime(maxMonth.year, maxMonth.month + 1, 1))) {
      keys.add(DateFormat('yyyy-MM').format(cur));
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    _allMonthKeys = keys;
  }

  void _scrollToFocusedMonth() {
    if (!_chartScrollController.hasClients) return;
    final key = DateFormat('yyyy-MM').format(_focusedMonth);
    final index = _allMonthKeys.indexOf(key);
    if (index == -1) return;

    final target = index * _totalBarWidth;
    final clamped =
        target.clamp(0.0, _chartScrollController.position.maxScrollExtent);
    _chartScrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _changeMonth(int delta) {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    final key = DateFormat('yyyy-MM').format(next);
    if (_allMonthKeys.contains(key)) {
      setState(() => _focusedMonth = next);
      _scrollToFocusedMonth();
      _scrollToTransactionList();
    }
  }

  void _scrollToTransactionList() {
    if (!_pageScrollController.hasClients) return;
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
    // 当月のこのタグの取引
    final currentMonthTransactions = widget.transactions
        .where((t) =>
            t.date.year == _focusedMonth.year &&
            t.date.month == _focusedMonth.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // 月別合計（このタグだけ）
    final Map<String, int> monthlyTagData = {for (final k in _allMonthKeys) k: 0};
    for (final t in widget.transactions) {
      final key = DateFormat('yyyy-MM').format(t.date);
      if (monthlyTagData.containsKey(key)) {
        monthlyTagData[key] = monthlyTagData[key]! + t.amount;
      }
    }

    // xの順序（昇順）
    final List<String> sortedMonthKeys = monthlyTagData.keys.toList()..sort();

    // 最大値（少しマージン）
    double maxY = monthlyTagData.values
        .fold<double>(0, (p, v) => v > p ? v.toDouble() : p);
    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY == 0) maxY = 1000;

    // バーグループ
    final List<BarChartGroupData> monthlyBarGroups = [
      for (int i = 0; i < sortedMonthKeys.length; i++)
        BarChartGroupData(
          x: i,
          showingTooltipIndicators:
              monthlyTagData[sortedMonthKeys[i]]! > 0 ? const [0] : const [],
          barRods: [
            BarChartRodData(
              toY: monthlyTagData[sortedMonthKeys[i]]!.toDouble(),
              color: widget.tagColor,
              width: _barGroupWidth,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
    ];

    final chartWidth = sortedMonthKeys.length * _totalBarWidth;

    final now = DateTime.now();
    final oneYearLater = DateTime(now.year + 1, now.month, 1);
    final isNextDisabled = _focusedMonth.year == oneYearLater.year &&
        _focusedMonth.month == oneYearLater.month;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.tagName} の月別推移'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _pageScrollController,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── グラフ ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                                getTooltipColor: (group) => Colors.transparent,
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
                              touchCallback:
                                  (FlTouchEvent event, BarTouchResponse? resp) {
                                if (resp?.spot != null &&
                                    event.isInterestedForInteractions) {
                                  final touched = resp!.spot!.touchedBarGroupIndex;
                                  if (touched < sortedMonthKeys.length) {
                                    final selectedKey =
                                        sortedMonthKeys[touched];
                                    final selectedMonth =
                                        DateTime.parse('$selectedKey-01');
                                    if (selectedMonth != _focusedMonth) {
                                      setState(
                                          () => _focusedMonth = selectedMonth);
                                      _scrollToFocusedMonth();
                                      _scrollToTransactionList();
                                    }
                                  }
                                }
                              },
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 ||
                                        idx >= sortedMonthKeys.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final key = sortedMonthKeys[idx];
                                    final isFocused =
                                        DateFormat('yyyy-MM')
                                                .format(_focusedMonth) ==
                                            key;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        DateFormat('yy/MM')
                                            .format(DateTime.parse('$key-01')),
                                        style: TextStyle(
                                          fontWeight: isFocused
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isFocused
                                              ? Theme.of(context).primaryColor
                                              : Colors.black,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16.0),

            // ── フォーカス月の切替 ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => _changeMonth(-1)),
                Text(
                  DateFormat('yyyy年MM月').format(_focusedMonth),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                isNextDisabled
                    ? const SizedBox(width: 48.0)
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () => _changeMonth(1),
                      ),
              ],
            ),
            const SizedBox(height: 16.0),

            // ── 当月の取引一覧 ───────────────────────────────
            Text(
              '${DateFormat('yyyy年MM月').format(_focusedMonth)} の取引',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            if (currentMonthTransactions.isEmpty)
              const Center(child: Text('この月の取引はありません。'))
            else
              ListView.builder(
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
                          color: t.type == 'income'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      subtitle: Text(
                          t.memo?.isNotEmpty == true ? t.memo! : 'メモなし'),
                    ),
                  );
                },
              ),
          ]),
        ),
      ),
    );
  }
}
