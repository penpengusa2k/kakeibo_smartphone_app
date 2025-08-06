import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/screens/tag_detail_page.dart';
import 'package:kakeibo_smartphone_app/screens/total_amount_detail_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _focusedMonth = DateTime.now();
  String _selectedTransactionType = 'expense'; // 'income' or 'expense'

  static const List<Color> _gentleColors = [
    Color(0xFF64B5F6), // Blue 300
    Color(0xFF81C784), // Green 300
    Color(0xFFAED581), // Light Green 300
    Color(0xFFFFD54F), // Amber 300
    Color(0xFFFF8A65), // Deep Orange 300
    Color(0xFF9575CD), // Deep Purple 300
    Color(0xFFF06292), // Pink 300
    Color(0xFF4DB6AC), // Teal 300
    Color(0xFF7986CB), // Indigo 300
    Color(0xFFB0BEC5), // Blue Grey 300
  ];

  @override
  void initState() {
    super.initState();
  }

  void _changeMonth(int months) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + months, 1);
    });
  }

  List<Transaction> _getFilteredTransactions(
      List<Transaction> allTransactions) {
    return allTransactions.where((t) {
      final transactionDate = t.date;
      final startOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final endOfMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
      final isInPeriod = transactionDate
              .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          transactionDate.isBefore(endOfMonth.add(const Duration(days: 1)));
      final isTypeSelected = t.type == _selectedTransactionType;
      return isInPeriod && isTypeSelected;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final filteredTransactions =
        _getFilteredTransactions(transactionViewModel.transactions);

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

    // 月別トレンドグラフデータ
    Map<String, Map<String, int>> monthlyData =
        {}; // { 'YYYY-MM': { 'income': amount, 'expense': amount } }
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      // 過去6ヶ月分のデータを取得
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(month);
      monthlyData[monthKey] = {'income': 0, 'expense': 0};
    }

    for (var t in transactionViewModel.transactions) {
      final monthKey = DateFormat('yyyy-MM').format(t.date);
      if (monthlyData.containsKey(monthKey)) {
        if (t.type == 'income') {
          monthlyData[monthKey]!['income'] =
              monthlyData[monthKey]!['income']! + t.amount;
        } else {
          monthlyData[monthKey]!['expense'] =
              monthlyData[monthKey]!['expense']! + t.amount;
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 期間選択
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
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
                ),
                // タイプ選択
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
                        backgroundColor: _selectedTransactionType == 'income'
                            ? Colors.green
                            : null,
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
                        backgroundColor: _selectedTransactionType == 'expense'
                            ? Colors.red
                            : null,
                      ),
                      child: const Text('支出'),
                    ),
                  ],
                ),

                // カテゴリ別グラフ
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16.0),
                        SizedBox(
                          height: 300, // 高さを調整
                          child: SfCircularChart(
                            series: <CircularSeries>[
                              PieSeries<MapEntry<String, double>, String>(
                                dataSource: dataByCategory.entries.toList(),
                                xValueMapper:
                                    (MapEntry<String, double> data, _) =>
                                        data.key,
                                yValueMapper:
                                    (MapEntry<String, double> data, _) =>
                                        data.value,
                                dataLabelMapper:
                                    (MapEntry<String, double> data, _) {
                                  final total =
                                      (_selectedTransactionType == 'income'
                                          ? totalIncome
                                          : totalExpense);
                                  final percentage = total > 0
                                      ? (data.value / total * 100)
                                      : 0.0;
                                  String percentageText;
                                  if (percentage > 0 && percentage < 0.1) {
                                    percentageText = '<0.1%';
                                  } else {
                                    percentageText =
                                        '${percentage.toStringAsFixed(1)}%';
                                  }
                                  return '${data.key}\n$percentageText';
                                },
                                dataLabelSettings: const DataLabelSettings(
                                  isVisible: true,
                                  labelPosition: ChartDataLabelPosition.outside,
                                  connectorLineSettings: ConnectorLineSettings(
                                    type: ConnectorType.curve,
                                    length: '10%',
                                  ),
                                ),
                                pointColorMapper: (MapEntry<String, double>
                                            data,
                                        index) =>
                                    _gentleColors[index % _gentleColors.length],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TotalAmountDetailPage(
                                  transactions: filteredTransactions,
                                  initialFocusedMonth: _focusedMonth,
                                  selectedTransactionType:
                                      _selectedTransactionType,
                                  allTags: dataByCategory.keys.toList(),
                                  tagColors: _gentleColors,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '合計',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${Formatter.formatAmount(_selectedTransactionType == 'income' ? totalIncome : totalExpense)}円',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: _selectedTransactionType ==
                                                      'income'
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 18.0, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                            final total = (_selectedTransactionType == 'income'
                                ? totalIncome
                                : totalExpense);
                            final percentage =
                                total > 0 ? (amount / total * 100) : 0.0;
                            String percentageText;
                            if (percentage > 0 && percentage < 0.1) {
                              percentageText = '<0.1';
                            } else {
                              percentageText = percentage.toStringAsFixed(1);
                            }
                            final tagTransactions = filteredTransactions
                                .where((t) => t.tag == tag)
                                .toList();

                            return Column(
                              children: [
                                ListTile(
                                  leading: Container(
                                    width: 50,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _gentleColors[dataByCategory.keys
                                              .toList()
                                              .indexOf(tag) %
                                          _gentleColors.length],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$percentageText%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(tag),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          '${Formatter.formatAmount(amount.toInt())}円'),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 16.0, color: Colors.grey),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TagDetailPage(
                                          tagName: tag,
                                          transactions: transactionViewModel
                                              .transactions
                                              .where((t) =>
                                                  t.tag == tag &&
                                                  t.type ==
                                                      _selectedTransactionType)
                                              .toList(),
                                          initialFocusedMonth: _focusedMonth,
                                          selectedTransactionType:
                                              _selectedTransactionType,
                                          tagColor: _gentleColors[dataByCategory
                                                  .keys
                                                  .toList()
                                                  .indexOf(tag) %
                                              _gentleColors.length],
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
                        const Text('月別収入・支出トレンド',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16.0),
                        SizedBox(
                          height: 200,
                          child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(),
                            series: <CartesianSeries>[
                              ColumnSeries<MapEntry<String, Map<String, int>>,
                                  String>(
                                dataSource: monthlyData.entries.toList(),
                                xValueMapper:
                                    (MapEntry<String, Map<String, int>> data,
                                            _) =>
                                        DateFormat('yy/MM').format(
                                            DateTime.parse('${data.key}-01')),
                                yValueMapper:
                                    (MapEntry<String, Map<String, int>> data,
                                            _) =>
                                        data.value['income'],
                                name: '収入',
                                color: Colors.green,
                              ),
                              ColumnSeries<MapEntry<String, Map<String, int>>,
                                  String>(
                                dataSource: monthlyData.entries.toList(),
                                xValueMapper:
                                    (MapEntry<String, Map<String, int>> data,
                                            _) =>
                                        DateFormat('yy/MM').format(
                                            DateTime.parse('${data.key}-01')),
                                yValueMapper:
                                    (MapEntry<String, Map<String, int>> data,
                                            _) =>
                                        data.value['expense'],
                                name: '支出',
                                color: Colors.red,
                              ),
                            ],
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
      ),
    );
  }
}
