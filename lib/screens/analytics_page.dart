import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Transaction> _filteredTransactions = [];

  @override
  void initState() {
    super.initState();
    _filterTransactions();
  }

  Future<void> _filterTransactions() async {
    final viewModel = Provider.of<TransactionViewModel>(context, listen: false);
    final allTransactions = await viewModel.getTransactions();

    setState(() {
      _filteredTransactions = allTransactions.where((t) {
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
            date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterTransactions();
    }
  }

  Map<String, double> _getExpenseByTag() {
    final Map<String, double> expenseByTag = {};
    for (var t in _filteredTransactions) {
      if (t.type == 'expense') {
        expenseByTag.update(t.tag, (value) => value + t.amount, ifAbsent: () => t.amount);
      }
    }
    return expenseByTag;
  }

  List<BarChartGroupData> _getBarChartData() {
    final Map<String, double> dailyIncome = {};
    final Map<String, double> dailyExpense = {};

    for (var t in _filteredTransactions) {
      final dateKey = DateFormat('MM/dd').format(t.date);
      if (t.type == 'income') {
        dailyIncome.update(dateKey, (value) => value + t.amount, ifAbsent: () => t.amount);
      } else {
        dailyExpense.update(dateKey, (value) => value + t.amount, ifAbsent: () => t.amount);
      }
    }

    final List<String> sortedDates = dailyIncome.keys.toList()..sort((a, b) => DateFormat('MM/dd').parse(a).compareTo(DateFormat('MM/dd').parse(b)));
    sortedDates.addAll(dailyExpense.keys.toList()..sort((a, b) => DateFormat('MM/dd').parse(a).compareTo(DateFormat('MM/dd').parse(b))));
    final uniqueSortedDates = sortedDates.toSet().toList()..sort((a, b) => DateFormat('MM/dd').parse(a).compareTo(DateFormat('MM/dd').parse(b)));

    return List.generate(uniqueSortedDates.length, (index) {
      final dateKey = uniqueSortedDates[index];
      final income = dailyIncome[dateKey] ?? 0.0;
      final expense = dailyExpense[dateKey] ?? 0.0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(toY: income, color: Colors.green, width: 8),
          BarChartRodData(toY: expense, color: Colors.red, width: 8),
        ],
        showingTooltipIndicators: [0, 1],
      );
    });
  }

  Future<void> _exportCsv() async {
    List<List<dynamic>> rows = [];
    rows.add(['日付', 'タイプ', '金額', 'タグ', 'メモ']);

    for (var t in _filteredTransactions) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type == 'income' ? '収入' : '支出',
        t.amount,
        t.tag,
        t.memo ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/kakeibo_data.csv';
    final file = File(path);
    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSVを ${path} にエクスポートしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseByTag = _getExpenseByTag();
    final totalExpense = expenseByTag.values.fold(0.0, (sum, amount) => sum + amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCsv,
            tooltip: 'CSVエクスポート',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 日付範囲選択
            ListTile(
              title: Text(
                  '期間: ${DateFormat('yyyy/MM/dd').format(_startDate)} - ${DateFormat('yyyy/MM/dd').format(_endDate)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDateRange(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: const BorderSide(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            // 収入・支出推移グラフ
            const Text(
              '収入・支出推移',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: _getBarChartData(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), // 日付が多すぎる場合があるので非表示
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // タグごとの支出割合円グラフ
            const Text(
              'タグごとの支出割合',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: expenseByTag.entries.map((entry) {
                    final percentage = (entry.value / totalExpense) * 100;
                    return PieChartSectionData(
                      color: Colors.red[300],
                      value: entry.value,
                      title: '${entry.key}\n${percentage.toStringAsFixed(1)}%',
                      radius: 80,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}