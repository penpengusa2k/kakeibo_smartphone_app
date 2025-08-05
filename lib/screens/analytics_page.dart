import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/screens/tag_detail_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _focusedMonth = DateTime.now();
  String _selectedTransactionType = 'expense'; // 'income' or 'expense'
  

  @override
  void initState() {
    super.initState();
  }

  void _changeMonth(int months) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + months, 1);
    });
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> allTransactions) {
    return allTransactions.where((t) {
      final transactionDate = t.date;
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
      final isInPeriod = transactionDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          transactionDate.isBefore(endOfMonth.add(const Duration(days: 1)));
      final isTypeSelected = t.type == _selectedTransactionType;
      return isInPeriod && isTypeSelected;
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
    Map<String, double> dataByCategory = {};
    for (var t in filteredTransactions) {
      dataByCategory[t.tag] = (dataByCategory[t.tag] ?? 0) + t.amount;
    }

    List<PieChartSectionData> pieChartSections = [];
    if (dataByCategory.isNotEmpty) {
      dataByCategory.forEach((tag, amount) {
        pieChartSections.add(
          PieChartSectionData(
            color: Colors.primaries[dataByCategory.keys.toList().indexOf(tag) % Colors.primaries.length],
            value: amount,
            title: '${Formatter.formatAmount(amount.toInt())}',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      });
    }

    // 月別トレンドグラフデータ
    Map<String, Map<String, int>> monthlyData = {}; // { 'YYYY-MM': { 'income': amount, 'expense': amount } }
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) { // 過去6ヶ月分のデータを取得
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);
      monthlyData[monthKey] = {'income': 0, 'expense': 0};
    }

    for (var t in transactionViewModel.transactions) {
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      if (monthlyData.containsKey(monthKey)) {
        if (t.type == 'income') {
          monthlyData[monthKey]!['income'] = monthlyData[monthKey]!['income']! + t.amount;
        } else {
          monthlyData[monthKey]!['expense'] = monthlyData[monthKey]!['expense']! + t.amount;
        }
      }
    }

    List<BarChartGroupData> monthlyBarGroups = [];
    List<String> sortedMonthKeys = monthlyData.keys.toList()..sort();

    for (int i = 0; i < sortedMonthKeys.length; i++) {
      final monthKey = sortedMonthKeys[i];
      final data = monthlyData[monthKey]!;
      monthlyBarGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data['income']!.toDouble(),
              color: Colors.green,
              width: 8,
              borderRadius: BorderRadius.zero,
            ),
            BarChartRodData(
              toY: data['expense']!.toDouble(),
              color: Colors.red,
              width: 8,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
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
              // 期間選択とタイプ選択
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    DateFormat('yyyy年MM月').format(_focusedMonth),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedTransactionType = 'income';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTransactionType == 'income' ? Colors.green : null,
                    ),
                    child: const Text('収入'),
                  ),
                  const SizedBox(width: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedTransactionType = 'expense';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTransactionType == 'expense' ? Colors.red : null,
                    ),
                    child: const Text('支出'),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),

              // サマリー
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedTransactionType == 'income')
                        _buildSummaryItem('収入', totalIncome, Colors.green)
                      else
                        _buildSummaryItem('支出', totalExpense, Colors.red),
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
                      Text(
                        'カテゴリ別${_selectedTransactionType == 'income' ? '収入' : '支出'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
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
                      Text(
                        '合計: ${Formatter.formatAmount(_selectedTransactionType == 'income' ? totalIncome : totalExpense)}円',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      // タグごとの内訳リスト
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: dataByCategory.keys.length,
                        itemBuilder: (context, index) {
                          final tag = dataByCategory.keys.elementAt(index);
                          final amount = dataByCategory[tag]!;
                          final total = (_selectedTransactionType == 'income' ? totalIncome : totalExpense);
                          final percentage = total > 0 ? (amount / total * 100) : 0.0;
                          String percentageText;
                          if (percentage > 0 && percentage < 0.1) {
                            percentageText = '<0.1';
                          } else {
                            percentageText = percentage.toStringAsFixed(1);
                          }
                          final tagTransactions = filteredTransactions.where((t) => t.tag == tag).toList();

                          return Column(
                            children: [
                              ListTile(
                                title: Text('$tag ($percentageText%)'),
                                trailing: Text('${Formatter.formatAmount(amount.toInt())}円'),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TagDetailPage(
                                        tagName: tag,
                                        transactions: transactionViewModel.transactions.where((t) => t.tag == tag && t.type == _selectedTransactionType).toList(),
                                        initialFocusedMonth: _focusedMonth,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // 月別トレンドグラフ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('月別収入・支出トレンド', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16.0),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            barGroups: monthlyBarGroups,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < sortedMonthKeys.length) {
                                      return Text(DateFormat('yy/MM').format(DateTime.parse('${sortedMonthKeys[value.toInt()]}-01')));
                                    }
                                    return const Text('');
                                  },
                                  interval: 1,
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
