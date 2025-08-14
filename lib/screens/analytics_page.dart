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

  bool _showSwipeHint = true;
  bool _userInteracted = false;

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
      return (now.year - 2000) * 12 + now.month - 1;
    } else {
      return now.year - 2000;
    }
  }

  // 新しいタイマー開始メソッド
  void _startSwipeHintTimer() {
    // 既にユーザー操作があった場合はヒントを表示しない
    if (_userInteracted) {
      return;
    }

    // ヒントを true に設定し、タイマーを開始
    setState(() {
      _showSwipeHint = true;
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      DateTime newFocusedDate;
      if (_viewType == _ViewType.month) {
        final year = 2000 + page ~/ 12;
        final month = page % 12 + 1;
        newFocusedDate = DateTime(year, month);
      } else {
        final year = 2000 + page;
        newFocusedDate = DateTime(year);
      }

      // ページ遷移＝ユーザー操作とみなし、ヒントを消す
      if (!_userInteracted) {
        _userInteracted = true;
        _showSwipeHint = false; // ここで _showSwipeHint を false に戻す
      }

      // 現在のページが分析画面のページになったらタイマーを開始
      if (_calculateInitialPageFromDate(newFocusedDate) == page) {
        _startSwipeHintTimer();
      }

      _focusedDate = newFocusedDate;
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
                      children: List<Widget>.generate(
                          DateTime.now().year - 2000 + 2, (int index) {
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
                  if (selectedDate.isAfter(oneYearLater)) {
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
            _pageController
                .jumpToPage(_calculateInitialPageFromDate(pickedDate));
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
                children: List<Widget>.generate(DateTime.now().year - 2000 + 2,
                    (int index) {
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
            _pageController
                .jumpToPage(_calculateInitialPageFromDate(pickedDate));
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


  Map<String, int> _calculateSummary(List<Transaction> allTransactions) {
    int totalIncome = 0;
    int totalExpense = 0;

    final transactionsInPeriod = allTransactions.where((t) {
      if (_viewType == _ViewType.month) {
        return t.date.year == _focusedDate.year &&
            t.date.month == _focusedDate.month;
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
              MaterialPageRoute(
                  builder: (context) => const BalanceAnalysisPage()),
            );
          },
        ),
        title: GestureDetector(
          onTap: () => _selectDate(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (_viewType == _ViewType.month)
                    _buildAnimatedView('年', false)
                  else
                    _buildAnimatedView('月', false),
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
                _viewType = _viewType == _ViewType.month
                    ? _ViewType.year
                    : _ViewType.month;
                _focusedDate = DateTime.now();
                _pageController.jumpToPage(_calculateInitialPage());
              });
            },
          ),
          const SizedBox(width: 8),
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
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 0.0), // 上に8.0、下に0.0のパディング
            child: Center(
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _selectedTransactionType,
                onValueChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedTransactionType = value;
                    });
                  }
                },
                children: const <String, Widget>{
                  'expense': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('支出'),
                  ),
                  'income': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('収入'),
                  ),
                },
              ),
            ),
          ),
          Expanded(
            // PointerDownでユーザー操作を検知してヒントを消す
            child: Listener(
              onPointerDown: (_) {
                if (!_userInteracted) {
                  setState(() {
                    _userInteracted = true;
                    _showSwipeHint = false; // ここで _showSwipeHint を false に戻す
                  });
                }
              },
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
                  return _buildChartPage(
                    context,
                    transactionViewModel,
                    currentDate,
                    // グラフ上のヒント表示はここから制御
                    showSwipeHint: _showSwipeHint && !_userInteracted,
                  );
                },
              ),
            ),
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
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
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
          alignment: isSelected ? Alignment.center : const Alignment(3.5, -3.5),
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
                padding: const EdgeInsets.only(top: 8.0),
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

  Widget _buildChartPage(
    BuildContext context,
    TransactionViewModel transactionViewModel,
    DateTime currentDate, {
    required bool showSwipeHint,
  }) {
    return _ChartPageContent(
      transactionViewModel: transactionViewModel,
      currentDate: currentDate,
      selectedTransactionType: _selectedTransactionType,
      focusedDate: _focusedDate,
      viewType: _viewType,
      gentleColors: _gentleColors,
      showSwipeHint: showSwipeHint,
    );
  }
}

class _ChartPageContent extends StatefulWidget {
  final TransactionViewModel transactionViewModel;
  final DateTime currentDate;
  final String selectedTransactionType;
  final DateTime focusedDate;
  final _ViewType viewType;
  final List<Color> gentleColors;
  final bool showSwipeHint;

  const _ChartPageContent({
    required this.transactionViewModel,
    required this.currentDate,
    required this.selectedTransactionType,
    required this.focusedDate,
    required this.viewType,
    required this.gentleColors,
    required this.showSwipeHint,
  });

  @override
  State<_ChartPageContent> createState() => _ChartPageContentState();
}

class _ChartPageContentState extends State<_ChartPageContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    final allTagsEver = widget.transactionViewModel.transactions
        .where((t) => t.type == widget.selectedTransactionType)
        .map((t) => t.tag)
        .toSet()
        .toList()
      ..sort();

    final filteredTransactions =
        widget.transactionViewModel.transactions.where((t) {
      bool isInPeriod;
      if (widget.viewType == _ViewType.month) {
        isInPeriod = t.date.year == widget.currentDate.year &&
            t.date.month == widget.currentDate.month;
      } else {
        isInPeriod = t.date.year == widget.currentDate.year;
      }
      return isInPeriod && t.type == widget.selectedTransactionType;
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
        padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ▼ グラフ上にだけヒントを重ねる（最大1.5秒／点滅なし）
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  SfCircularChart(
                    annotations: dataByCategory.isEmpty
                        ? <CircularChartAnnotation>[
                            CircularChartAnnotation(
                                widget: const Text('表示するデータがありません'))
                          ]
                        : null,
                    series: <CircularSeries>[
                      PieSeries<MapEntry<String, double>, String>(
                        dataSource: sortedTagsForMonth
                            .map((tag) => MapEntry(tag, dataByCategory[tag]!))
                            .toList(),
                        xValueMapper: (MapEntry<String, double> data, _) =>
                            data.key,
                        yValueMapper: (MapEntry<String, double> data, _) =>
                            data.value,
                        dataLabelMapper: (MapEntry<String, double> data, _) {
                          final total = totalAmount;
                          final percentage =
                              total > 0 ? (data.value / total * 100) : 0.0;
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
                        pointColorMapper: (MapEntry<String, double> data,
                                int index) =>
                            widget.gentleColors[allTagsEver.indexOf(data.key) %
                                widget.gentleColors.length],
                      )
                    ],
                  ),
                  if (widget.showSwipeHint) const _GraphSwipeHintOverlay(),
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
                      transactions: widget.transactionViewModel.transactions
                          .where(
                              (t) => t.type == widget.selectedTransactionType)
                          .toList(),
                      initialFocusedMonth: widget.focusedDate,
                      selectedTransactionType: widget.selectedTransactionType,
                      allTags: allTagsEver,
                      tagColors: widget.gentleColors,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('合計',
                          style: Theme.of(context).textTheme.titleMedium),
                      Row(
                        children: [
                          Text(
                            '${Formatter.formatAmount(totalAmount)}円',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      widget.selectedTransactionType == 'income'
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
                  final percentage = total > 0 ? (amount / total * 100) : 0.0;
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
                                transactions: widget
                                    .transactionViewModel.transactions
                                    .where((t) =>
                                        t.tag == tag &&
                                        t.type ==
                                            widget.selectedTransactionType)
                                    .toList(),
                                initialFocusedMonth: widget.focusedDate,
                                selectedTransactionType:
                                    widget.selectedTransactionType,
                                tagColor: widget.gentleColors[
                                    allTagsEver.indexOf(tag) %
                                        widget.gentleColors.length],
                              ),
                            ),
                          );
                        },
                        leading: Container(
                          width: 50,
                          height: 24,
                          decoration: BoxDecoration(
                            color: widget.gentleColors[
                                allTagsEver.indexOf(tag) %
                                    widget.gentleColors.length],
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
                            Text('${Formatter.formatAmount(amount.toInt())}円'),
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

// ▼ グラフ上にだけ出すスワイプヒント（点滅なし／タッチ非干渉）
class _GraphSwipeHintOverlay extends StatelessWidget {
  const _GraphSwipeHintOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: 100.0),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left, color: Colors.white),
                  SizedBox(width: 8),
                  Text('左右にスワイプ',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ), // DecoratedBox の閉じ括弧
        ), // Center の閉じ括弧
      ), // Padding の閉じ括弧
    ); // IgnorePointer の閉じ括弧
  }
}
