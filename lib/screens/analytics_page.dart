import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = '今月';
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _setPeriodToCurrentMonth();
  }

  void _setPeriodToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0); // 今月の最終日
      _selectedPeriod = '今月';
    });
  }

  void _setPeriodToLastMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month - 1, 1);
      _endDate = DateTime(now.year, now.month, 0); // 先月の最終日
      _selectedPeriod = '先月';
    });
  }

  void _setPeriodToCurrentYear() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 12, 31);
      _selectedPeriod = '今年';
    });
  }

  Future<void> _selectCustomPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'カスタム';
      });
    }
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> allTransactions) {
    return allTransactions.where((t) {
      final transactionDate = t.date;
      final isInPeriod = transactionDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          transactionDate.isBefore(_endDate.add(const Duration(days: 1)));
      final isTagSelected = _selectedTags.isEmpty || _selectedTags.contains(t.tag);
      return isInPeriod && isTagSelected;
    }).toList();
  }

  Future<void> _exportCsv(List<Transaction> transactions) async {
    List<List<dynamic>> rows = [];
    rows.add(['日付', 'タイプ', '金額', 'タグ', 'メモ']);

    for (var t in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type == 'income' ? '収入' : '支出',
        t.amount,
        t.tag,
        t.memo ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/kakeibo_data.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: '家計簿データ');
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final filteredTransactions = _getFilteredTransactions(transactionViewModel.transactions);

    // サマリー計算
    int totalIncome = 0;
    int totalExpense = 0;
    for (var t in filteredTransactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    int balance = totalIncome - totalExpense;

    // カテゴリ別グラフデータ
    Map<String, double> expenseByCategory = {};
    for (var t in filteredTransactions.where((t) => t.type == 'expense')) {
      expenseByCategory[t.tag] = (expenseByCategory[t.tag] ?? 0) + t.amount;
    }

    List<PieChartSectionData> pieChartSections = [];
    if (expenseByCategory.isNotEmpty) {
      expenseByCategory.forEach((tag, amount) {
        pieChartSections.add(
          PieChartSectionData(
            color: Colors.primaries[expenseByCategory.keys.toList().indexOf(tag) % Colors.primaries.length],
            value: amount,
            title: '${Formatter.formatAmount(amount.toInt())}',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      });
    }

    // 支出トレンドグラフデータ (簡易版: 日ごとの棒グラフ)
    Map<DateTime, int> dailyExpense = {};
    for (var t in filteredTransactions.where((t) => t.type == 'expense')) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      dailyExpense[date] = (dailyExpense[date] ?? 0) + t.amount;
    }

    List<BarChartGroupData> barChartGroups = [];
    List<FlSpot> lineChartSpots = []; // 折れ線グラフ用
    List<DateTime> sortedDates = dailyExpense.keys.toList()..sort();

    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final amount = dailyExpense[date]!;
      barChartGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amount.toDouble(),
              color: Colors.red,
              width: 10,
            ),
          ],
        ),
      );
      lineChartSpots.add(FlSpot(i.toDouble(), amount.toDouble()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _exportCsv(filteredTransactions),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 期間選択
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: _setPeriodToCurrentMonth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPeriod == '今月' ? Colors.blue : null,
                    ),
                    child: const Text('今月'),
                  ),
                  ElevatedButton(
                    onPressed: _setPeriodToLastMonth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPeriod == '先月' ? Colors.blue : null,
                    ),
                    child: const Text('先月'),
                  ),
                  ElevatedButton(
                    onPressed: _setPeriodToCurrentYear,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPeriod == '今年' ? Colors.blue : null,
                    ),
                    child: const Text('今年'),
                  ),
                  ElevatedButton(
                    onPressed: _selectCustomPeriod,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPeriod == 'カスタム' ? Colors.blue : null,
                    ),
                    child: const Text('カスタム'),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Text(
                '期間: ${DateFormat('yyyy/MM/dd').format(_startDate)} - ${DateFormat('yyyy/MM/dd').format(_endDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16.0),

              // サマリー
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('収入', totalIncome, Colors.green),
                      _buildSummaryItem('支出', totalExpense, Colors.red),
                      _buildSummaryItem('収支', balance, Colors.blue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // カテゴリ別グラフ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('カテゴリ別支出', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: pieChartSections,
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      // タグフィルタ
                      Wrap(
                        spacing: 8.0,
                        children: transactionViewModel.tags.where((tag) => tag.type == 'expense').map((tag) {
                          final isSelected = _selectedTags.contains(tag.name);
                          return FilterChip(
                            label: Text(tag.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTags.add(tag.name);
                                } else {
                                  _selectedTags.remove(tag.name);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // 支出トレンドグラフ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('支出トレンド', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            barGroups: barChartGroups,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < sortedDates.length) {
                                      return Text(DateFormat('MM/dd').format(sortedDates[value.toInt()]));
                                    }
                                    return const Text('');
                                  },
                                  interval: (sortedDates.isEmpty ? 1 : (sortedDates.length / 5).ceilToDouble()), // 5つ程度のラベルを表示 (最低1)
                                ),
                              ),
                            ),
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, int amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
        Text(
          Formatter.formatAmount(amount),
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
