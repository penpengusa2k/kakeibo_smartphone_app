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
import 'package:kakeibo_smartphone_app/screens/balance_analysis_page.dart';

enum _ViewType { month, year }

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  DateTime _focusedDate = DateTime.now();
  String _selectedTransactionType = 'expense'; // 'income' or 'expense'
  _ViewType _viewType = _ViewType.month;
  late PageController _pageController;

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
    _pageController = PageController(initialPage: _calculateInitialPage());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _calculateInitialPage() {
    final now = DateTime.now();
    if (_viewType == _ViewType.month) {
      return (now.year - 2000) * 12 + now.month -1;
    } else {
      return now.year - 2000;
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      if (_viewType == _ViewType.month) {
        final year = 2000 + page ~/ 12;
        final month = page % 12 + 1;
        _focusedDate = DateTime(year, month);
      } else {
        final year = 2000 + page;
        _focusedDate = DateTime(year);
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _focusedDate.year;
    int selectedMonth = _focusedDate.month;

    if (_viewType == _ViewType.month) {
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
            _focusedDate = pickedDate;
            _pageController.jumpToPage(_calculateInitialPageFromDate(pickedDate));
          });
        }
      });
    } else {
      // Year Picker
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('年を選択', textAlign: TextAlign.center),
            content: SizedBox(
              width: 150,
              height: 200,
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
            actions: <Widget>[
               TextButton(
                child: const Text('今年へ戻る'),
                onPressed: () => Navigator.of(context).pop(DateTime.now()),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                   final oneYearLater = DateTime(now.year + 1);
                  final selectedDate = DateTime(selectedYear);
                  if (selectedDate.isAfter(oneYearLater)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('1年後より未来の年は選択できません')),
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
            _focusedDate = pickedDate;
             _pageController.jumpToPage(_calculateInitialPageFromDate(pickedDate));
          });
        }
      });
    }
  }

  int _calculateInitialPageFromDate(DateTime date) {
    if (_viewType == _ViewType.month) {
      return (date.year - 2000) * 12 + date.month - 1;
    } else {
      return date.year - 2000;
    }
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> allTransactions) {
    return allTransactions.where((t) {
      bool isInPeriod;
      if (_viewType == _ViewType.month) {
        isInPeriod = t.date.year == _focusedDate.year && t.date.month == _focusedDate.month;
      } else {
        isInPeriod = t.date.year == _focusedDate.year;
      }
      final isTypeSelected = t.type == _selectedTransactionType;
      return isInPeriod && isTypeSelected;
    }).toList();
  }
  
  Map<String, int> _calculateSummary(List<Transaction> allTransactions) {
    int totalIncome = 0;
    int totalExpense = 0;
    
    final transactionsInPeriod = allTransactions.where((t) {
       if (_viewType == _ViewType.month) {
        return t.date.year == _focusedDate.year && t.date.month == _focusedDate.month;
      } else {
        return t.date.year == _focusedDate.year;
      }
    }).toList();

    for (var t in transactionsInPeriod) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final summary = _calculateSummary(transactionViewModel.transactions);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 26),
              Text('支出推移', style: TextStyle(fontSize: 9)),
            ],
          ),
          tooltip: '支出推移の分析',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BalanceAnalysisPage()),
            );
          },
        ),
        title: GestureDetector(
          onTap: () => _selectDate(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 透明なアイコンを左に置いて、テキストが中央に来るように調整
              const Opacity(
                opacity: 0,
                child: Icon(Icons.arrow_drop_down),
              ),
              Text(
                _viewType == _ViewType.month 
                  ? DateFormat('yyyy年MM月').format(_focusedDate)
                  : DateFormat('yyyy年').format(_focusedDate),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Icon(Icons.arrow_drop_down)
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: SizedBox(
              width: 48, // Stackの領域を確保
              height: 48,
              child: Stack(
                clipBehavior: Clip.none, // はみ出した部分も表示する
                alignment: Alignment.center,
                children: [
                  // 非選択のものを先に描画 (奥)
                  if (_viewType == _ViewType.month)
                    _buildAnimatedView('年', false)
                  else
                    _buildAnimatedView('月', false),
                  // 選択中のものを後に描画 (手前)
                  if (_viewType == _ViewType.month)
                    _buildAnimatedView('月', true)
                  else
                    _buildAnimatedView('年', true),
                ],
              ),
            ),
            tooltip: '月/年 表示の切り替え',
            onPressed: () {
              setState(() {
                _viewType = _viewType == _ViewType.month ? _ViewType.year : _ViewType.month;
                _focusedDate = DateTime.now();
                _pageController.jumpToPage(_calculateInitialPage());
              });
            },
          ),
          const SizedBox(width: 8), // 右端に余白を追加
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('収入', summary['income']!, Colors.green),
                  _buildSummaryItem('支出', summary['expense']!, Colors.red),
                  _buildSummaryItem('収支', summary['balance']!, Colors.blue),
                ],
              ),
            ),
          ),
          // タイプ選択 (支出/収入トグル)
          LayoutBuilder(
            builder: (context, constraints) {
              const double borderWidth = 1.0;
              final double buttonWidth = (constraints.maxWidth - (borderWidth * 3)) / 2;
              return ToggleButtons(
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
                isSelected: [
                  _selectedTransactionType == 'expense',
                  _selectedTransactionType == 'income'
                ],
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
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) {
                DateTime currentDate;
                 if (_viewType == _ViewType.month) {
                  final year = 2000 + page ~/ 12;
                  final month = page % 12 + 1;
                  currentDate = DateTime(year, month);
                } else {
                  final year = 2000 + page;
                  currentDate = DateTime(year);
                }
                return _buildChartPage(context, transactionViewModel, currentDate);
              },
            )
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, int amount, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${Formatter.formatAmount(amount)}円',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
  
  Widget _buildAnimatedView(String text, bool isSelected) {
    final Color activeColor = Colors.orange.shade700; // 少し濃いオレンジ
    final Color? inactiveColor = Theme.of(context).textTheme.titleLarge?.color;

    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.7,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isSelected ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: AnimatedAlign(
          alignment: isSelected ? Alignment.center : const Alignment(3.5, -3.5), // さらに離す
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 32,
                color: isSelected ? activeColor : inactiveColor,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0), // さらに下にずらす
                child: Text(
                  text,
                  style: TextStyle(
                    color: isSelected ? activeColor : inactiveColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartPage(BuildContext context, TransactionViewModel transactionViewModel, DateTime currentDate) {
    
    final allTagsEver = transactionViewModel.transactions
        .where((t) => t.type == _selectedTransactionType)
        .map((t) => t.tag)
        .toSet()
        .toList()
      ..sort();

    final filteredTransactions = transactionViewModel.transactions.where((t) {
      bool isInPeriod;
      if (_viewType == _ViewType.month) {
        isInPeriod = t.date.year == currentDate.year && t.date.month == currentDate.month;
      } else {
        isInPeriod = t.date.year == currentDate.year;
      }
      return isInPeriod && t.type == _selectedTransactionType;
    }).toList();

    int totalAmount = 0;
    for (var t in filteredTransactions) {
      totalAmount += t.amount;
    }

    Map<String, double> dataByCategory = {};
    for (var t in filteredTransactions) {
      dataByCategory[t.tag] = (dataByCategory[t.tag] ?? 0) + t.amount;
    }

    final sortedTagsForMonth = dataByCategory.keys.toList()..sort();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                    height: 300,
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
                            final total = totalAmount;
                            final percentage = total > 0
                                ? (data.value / total * 100) : 0.0;
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
                // 左矢印
                Positioned(
                  left: 0,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: 0.5,
                        child: Icon(
                          Icons.arrow_back_ios,
                          size: 40,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
                // 右矢印
                Positioned(
                  right: 0,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Opacity(
                        opacity: 0.5,
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 40,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TotalAmountDetailPage(
                      transactions: transactionViewModel.transactions.where((t) => t.type == _selectedTransactionType).toList(),
                      initialFocusedMonth: _focusedDate,
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
                            '${Formatter.formatAmount(totalAmount)}円',
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
            ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedTagsForMonth.length,
                itemBuilder: (context, index) {
                  final tag = sortedTagsForMonth[index];
                  final amount = dataByCategory[tag]!;
                  final total = totalAmount;
                  final percentage =
                      total > 0 ? (amount / total * 100) : 0.0;
                  String percentageText;
                  if (percentage > 0 && percentage < 0.1) {
                    percentageText = '<0.1';
                  } else {
                    percentageText = percentage.toStringAsFixed(1);
                  }
                  return Column(
                    children: [
                      ListTile(
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
                                initialFocusedMonth: _focusedDate,
                                selectedTransactionType:
                                    _selectedTransactionType,
                                tagColor: _gentleColors[
                                    allTagsEver.indexOf(tag) %
                                        _gentleColors.length],
                              ),
                            ),
                          );
                        },
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
                      ),
                    ],
                  );
                }, 
              ),
          ],
        ),
      ),
    );
  }
}
