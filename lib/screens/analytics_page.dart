import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/screens/tag_detail_page.dart';
import 'package:kakeibo_smartphone_app/screens/total_amount_detail_page.dart';
import 'package:flutter/cupertino.dart'; // CupertinoPickerのために追加

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _focusedMonth = DateTime.now();
  String _selectedTransactionType = 'expense'; // 'income' or 'expense'

  static const List<Color> _gentleColors = [
    Color(0xFFE57373), // Red 300
    Color(0xFF64B5F6), // Blue 300
    Color(0xFF81C784), // Green 300
    Color(0xFFFFB74D), // Orange 300
    Color(0xFF9575CD), // Deep Purple 300
    Color(0xFF4DB6AC), // Teal 300
    Color(0xFFFFF176), // Yellow 300
    Color(0xFFF06292), // Pink 300
    Color(0xFFBA68C8), // Purple 300
    Color(0xFF7986CB), // Indigo 300
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _focusedMonth.year;
    int selectedMonth = _focusedMonth.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('年月を選択', textAlign: TextAlign.center),
          content: SizedBox(
            width: 300,
            height: 200,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedYear - 2000),
                    itemExtent: 40.0,
                    onSelectedItemChanged: (int index) {
                      selectedYear = 2000 + index;
                    },
                    children: List<Widget>.generate(now.year - 2000 + 2, (int index) { // 来年まで表示
                      return Center(
                          child: Text('${2000 + index}年',
                              style: const TextStyle(fontSize: 20)));
                    }),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                        initialItem: selectedMonth - 1),
                    itemExtent: 40.0,
                    onSelectedItemChanged: (int index) {
                      selectedMonth = index + 1;
                    },
                    children: List<Widget>.generate(12, (int index) {
                      return Center(
                          child: Text('${index + 1}月',
                              style: const TextStyle(fontSize: 20)));
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('今月へ戻る'),
              onPressed: () => Navigator.of(context).pop(DateTime.now()),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final oneYearLater = DateTime(now.year + 1, now.month, 1);
                final selectedDate = DateTime(selectedYear, selectedMonth);
                if (selectedDate.isAfter(oneYearLater)) { // 1年後より未来は選択不可
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('1年後より未来の月は選択できません')),
                  );
                  return;
                }
                Navigator.of(context).pop(selectedDate);
              },
              child: const Text('決定'),
            ),
          ],
        );
      },
    ).then((pickedDate) {
      if (pickedDate != null && pickedDate is DateTime) {
        setState(() {
          _focusedMonth = pickedDate;
        });
      }
    });
  }

  // 日付のズレを修正した_getFilteredTransactions関数
  List<Transaction> _getFilteredTransactions(
      List<Transaction> allTransactions) {
    return allTransactions.where((t) {
      final isInPeriod = t.date.year == _focusedMonth.year &&
          t.date.month == _focusedMonth.month;
      final isTypeSelected = t.type == _selectedTransactionType;
      return isInPeriod && isTypeSelected;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);

    // 選択中の収支タイプにおける、全期間のタグリストを作成し、ソートする
    final allTagsEver = transactionViewModel.transactions
        .where((t) => t.type == _selectedTransactionType)
        .map((t) => t.tag)
        .toSet()
        .toList()
      ..sort();

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
    
    // 表示用に、その月に存在するタグだけをソートする
    final sortedTagsForMonth = dataByCategory.keys.toList()..sort();

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

    // 右矢印ボタンの有効/無効判定ロジック
    final oneYearLater = DateTime(now.year + 1, now.month, 1);
    final isNextDisabled = _focusedMonth.year == oneYearLater.year && _focusedMonth.month == oneYearLater.month;

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
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(
                                _focusedMonth.year, _focusedMonth.month - 1, 1);
                          });
                        },
                      ),
                      GestureDetector(
                        onTap: () => _selectMonth(context),
                        child: Text(
                          DateFormat('yyyy年MM月').format(_focusedMonth),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      isNextDisabled
                        ? const SizedBox(width: 48.0) // IconButtonのスペースを確保
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              setState(() {
                                _focusedMonth = DateTime(
                                    _focusedMonth.year, _focusedMonth.month + 1, 1);
                              });
                            },
                          ),
                    ],
                  ),
                ),
                // タイプ選択
                                LayoutBuilder(
                  builder: (context, constraints) {
                    const double borderWidth = 1.0;
                    // Total borders = 3 (left, middle, right)
                    final double buttonWidth = (constraints.maxWidth - (borderWidth * 3)) / 2;
                    return ToggleButtons(
                      isSelected: [
                        _selectedTransactionType == 'expense',
                        _selectedTransactionType == 'income'
                      ],
                      onPressed: (index) {
                        setState(() {
                          _selectedTransactionType = index == 0 ? 'expense' : 'income';
                        });
                      },
                      fillColor: _selectedTransactionType == 'expense'
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      selectedColor: _selectedTransactionType == 'expense'
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                      color: Colors.black87,
                      borderColor: Colors.grey.shade400,
                      selectedBorderColor: _selectedTransactionType == 'expense'
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8.0),
                      borderWidth: borderWidth,
                      renderBorder: true,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: const Center(child: Text('支出')),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: const Center(child: Text('収入')),
                        ),
                      ],
                    );
                  },
                ),

                // カテゴリ別グラフ
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            height: 300, // 高さを調整
                            child: SfCircularChart(
                              annotations: dataByCategory.isEmpty
                                  ? <CircularChartAnnotation>[
                                      CircularChartAnnotation(
                                          widget: const Text('表示するデータがありません'))
                                    ]
                                  : null,
                              series: <CircularSeries>[
                                PieSeries<MapEntry<String, double>, String>(
                                  dataSource: sortedTagsForMonth
                                      .map((tag) =>
                                          MapEntry(tag, dataByCategory[tag]!))
                                      .toList(),
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
                                    labelPosition:
                                        ChartDataLabelPosition.outside,
                                    connectorLineSettings: ConnectorLineSettings(
                                      type: ConnectorType.curve,
                                      length: '10%',
                                    ),
                                  ),
                                  pointColorMapper:
                                      (MapEntry<String, double> data, _) =>
                                          _gentleColors[allTagsEver
                                                  .indexOf(data.key) %
                                              _gentleColors.length],
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
                                  transactions: transactionViewModel.transactions.where((t) => t.type == _selectedTransactionType).toList(),
                                  initialFocusedMonth: _focusedMonth,
                                  selectedTransactionType:
                                      _selectedTransactionType,
                                  allTags: allTagsEver,
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
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
                        if (dataByCategory.isNotEmpty)  
                        // タグごとの内訳リスト
                        ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedTagsForMonth.length,
                            itemBuilder: (context, index) {
                              final tag = sortedTagsForMonth[index];
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
                                        color: _gentleColors[allTagsEver.indexOf(tag) % _gentleColors.length],
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
                                            tagColor: _gentleColors[
                                                allTagsEver.indexOf(tag) %
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
                              ColumnSeries<MapEntry<String, Map<String, int>>, String>(
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
                              ColumnSeries<MapEntry<String, Map<String, int>>, String>(
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
