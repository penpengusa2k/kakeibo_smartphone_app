import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' as charts;
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:flutter/cupertino.dart';

enum Period {
  day,
  month,
  year,
}

class BalanceAnalysisPage extends StatefulWidget {
  const BalanceAnalysisPage({super.key});

  @override
  State<BalanceAnalysisPage> createState() => _BalanceAnalysisPageState();
}

class _BalanceAnalysisPageState extends State<BalanceAnalysisPage> {
  DateTime _focusedDate = DateTime.now();
  Period _selectedPeriod = Period.month;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 日付選択ダイアログ
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _focusedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _focusedDate) {
      setState(() {
        _focusedDate = picked;
      });
    }
  }

  // 期間選択ダイアログ (月・年)
  Future<void> _selectPeriod(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _focusedDate.year;
    int selectedMonth = _focusedDate.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('期間を選択', textAlign: TextAlign.center),
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
                        now.year - 2000 + 2, (int index) {
                      return Center(
                          child: Text('${2000 + index}年',
                              style: const TextStyle(fontSize: 20)));
                    }),
                  ),
                ),
                if (_selectedPeriod != Period.year)
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
              onPressed: () => Navigator.of(context).pop(DateTime.now()),
              child: const Text('今月へ戻る'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final oneYearLater = DateTime(now.year + 1, now.month, 1);
                DateTime selectedDate;
                if (_selectedPeriod == Period.year) {
                  selectedDate = DateTime(selectedYear, 1, 1);
                } else {
                  selectedDate = DateTime(selectedYear, selectedMonth);
                }

                if (selectedDate.isAfter(oneYearLater)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('1年後より未来の期間は選択できません')),
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
        if (!mounted) return;
        setState(() {
          _focusedDate = pickedDate;
        });
      }
    });
  }

  // 期間に応じたチャートデータを取得
  List<ChartData> _getChartData(List<Transaction> transactions) {
    Map<DateTime, Map<String, int>> aggregatedData = {};

    for (var t in transactions) {
      DateTime keyDate;
      switch (_selectedPeriod) {
        case Period.day:
          keyDate = DateTime(t.date.year, t.date.month, t.date.day);
          break;
        case Period.month:
          keyDate = DateTime(t.date.year, t.date.month, 1);
          break;
        case Period.year:
          keyDate = DateTime(t.date.year, 1, 1);
          break;
      }
      aggregatedData.putIfAbsent(keyDate, () => {'income': 0, 'expense': 0});
      if (t.type == 'income') {
        aggregatedData[keyDate]!['income'] =
            aggregatedData[keyDate]!['income']! + t.amount;
      } else {
        aggregatedData[keyDate]!['expense'] =
            aggregatedData[keyDate]!['expense']! + t.amount;
      }
    }

    // キーを日付としてソート
    final sortedKeys = aggregatedData.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    // ChartDataのリストを作成
    return sortedKeys.map((keyDate) {
      final income = aggregatedData[keyDate]!['income']!;
      final expense =
          aggregatedData.containsKey(keyDate) ? aggregatedData[keyDate]!['expense']! : 0;
      final balance = income - expense;

      return ChartData(keyDate, income, expense, balance);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final List<ChartData> chartData =
        _getChartData(transactionViewModel.transactions);

    List<ChartData> displayedChartData = chartData;

    // X軸のフォーマット
    String xAxisLabelFormat;
    if (_selectedPeriod == Period.day) {
      xAxisLabelFormat = 'MM/dd';
    } else if (_selectedPeriod == Period.month) {
      xAxisLabelFormat = 'yy/MM';
    } else {
      xAxisLabelFormat = 'yyyy';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('収支分析'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 期間選択トグルボタン
                Center(
                  child: ToggleButtons(
                    isSelected: Period.values
                        .map((period) => _selectedPeriod == period)
                        .toList(),
                    onPressed: (int index) {
                      setState(() {
                        _selectedPeriod = Period.values[index];
                        _focusedDate = DateTime.now();
                      });
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    children: const <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('日'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('月'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('年'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                // 期間ナビゲーション
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedPeriod == Period.day) {
                              _focusedDate =
                                  _focusedDate.subtract(const Duration(days: 1));
                            } else if (_selectedPeriod == Period.month) {
                              _focusedDate = DateTime(
                                  _focusedDate.year, _focusedDate.month - 1, _focusedDate.day);
                            } else {
                              _focusedDate = DateTime(
                                  _focusedDate.year - 1, _focusedDate.month, _focusedDate.day);
                            }
                          });
                        },
                        icon: const Icon(Icons.arrow_back_ios),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_selectedPeriod == Period.day) {
                            _selectDate(context);
                          } else if (_selectedPeriod == Period.month ||
                              _selectedPeriod == Period.year) {
                            _selectPeriod(context);
                          }
                        },
                        child: Text(
                          _selectedPeriod == Period.day
                              ? DateFormat('yyyy年MM月dd日').format(_focusedDate)
                              : _selectedPeriod == Period.month
                                  ? DateFormat('yyyy年MM月').format(_focusedDate)
                                  : DateFormat('yyyy年').format(_focusedDate),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedPeriod == Period.day) {
                              _focusedDate = _focusedDate.add(const Duration(days: 1));
                            } else if (_selectedPeriod == Period.month) {
                              _focusedDate = DateTime(
                                  _focusedDate.year, _focusedDate.month + 1, _focusedDate.day);
                            } else {
                              _focusedDate = DateTime(
                                  _focusedDate.year + 1, _focusedDate.month, _focusedDate.day);
                            }
                          });
                        },
                        icon: const Icon(Icons.arrow_forward_ios),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          _selectedPeriod == Period.day
                              ? '日別収支トレンド'
                              : _selectedPeriod == Period.month
                                  ? '月別収支トレンド'
                                  : '年別収支トレンド',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          height: 300,
                          child: charts.SfCartesianChart(
                            enableAxisAnimation: false,
                            primaryXAxis: charts.DateTimeAxis(
                              dateFormat: DateFormat(xAxisLabelFormat),
                              intervalType: charts.DateTimeIntervalType.auto,
                            ),
                            series: <charts.CartesianSeries>[
                              // 収入の棒グラフ
                              charts.ColumnSeries<ChartData, DateTime>(
                                dataSource: displayedChartData,
                                xValueMapper: (ChartData data, _) => data.date,
                                yValueMapper: (ChartData data, _) => data.income,
                                name: '収入',
                                color: Colors.green,
                                animationDuration: 0,
                              ),
                              // 支出の棒グラフ (yValueMapperに負の値を使用)
                              charts.ColumnSeries<ChartData, DateTime>(
                                dataSource: displayedChartData,
                                xValueMapper: (ChartData data, _) => data.date,
                                yValueMapper: (ChartData data, _) => -data.expense,
                                name: '支出',
                                color: Colors.red,
                                animationDuration: 0,
                              ),
                              // 収支の折れ線グラフ
                              charts.LineSeries<ChartData, DateTime>(
                                dataSource: displayedChartData,
                                xValueMapper: (ChartData data, _) => data.date,
                                yValueMapper: (ChartData data, _) => data.balance,
                                name: '収支',
                                color: Colors.blue,
                                pointColorMapper: (ChartData data, _) {
                                  return data.balance >= 0 ? Colors.green : Colors.red;
                                },
                                markerSettings: const charts.MarkerSettings(isVisible: true),
                                dataLabelSettings: const charts.DataLabelSettings(isVisible: true),
                                animationDuration: 0,
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

class ChartData {
  ChartData(this.date, this.income, this.expense, this.balance);
  final DateTime date;
  final int income;
  final int expense;
  final int balance;
}
