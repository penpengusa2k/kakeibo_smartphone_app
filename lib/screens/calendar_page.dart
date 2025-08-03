import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Transaction>> _transactionsByDate = {};
  double _monthlyIncome = 0.0;
  double _monthlyExpense = 0.0;
  List<Transaction> _selectedDayTransactions = [];
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadMonthlyData(_focusedDay);
    _onDaySelected(DateTime.now());
  }

  Future<void> _loadMonthlyData(DateTime month) async {
    final viewModel = Provider.of<TransactionViewModel>(context, listen: false);
    final transactions = await viewModel.getTransactionsByMonth(month);

    _transactionsByDate.clear();
    _monthlyIncome = 0.0;
    _monthlyExpense = 0.0;

    for (var transaction in transactions) {
      final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      _transactionsByDate.putIfAbsent(date, () => []).add(transaction);

      if (transaction.type == 'income') {
        _monthlyIncome += transaction.amount;
      } else {
        _monthlyExpense += transaction.amount;
      }
    }

    setState(() {});
  }

  void _onDaySelected(DateTime selectedDay) async {
    final viewModel = Provider.of<TransactionViewModel>(context, listen: false);
    final dailyTransactions = await viewModel.getTransactionsByDate(selectedDay);

    setState(() {
      _selectedDay = selectedDay;
      _selectedDayTransactions = dailyTransactions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('カレンダー'),
        ),
        body: Column(
          children: [
            _buildMonthlySummaryCard(),
            Expanded(
              child: ListView(
                children: [
                  _buildCalendarSection(),
                  const SizedBox(height: 16),
                  _buildTableSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummaryCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '${DateFormat('yyyy年MM月').format(_focusedDay)}の集計',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('収入', style: TextStyle(color: Colors.green)),
                    Text('${_monthlyIncome.toStringAsFixed(0)}円', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                Column(
                  children: [
                    const Text('支出', style: TextStyle(color: Colors.red)),
                    Text('${_monthlyExpense.toStringAsFixed(0)}円', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                Column(
                  children: [
                    const Text('収支'),
                    Text('${(_monthlyIncome - _monthlyExpense).toStringAsFixed(0)}円',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstWeekday = firstDay.weekday;
    final totalItems = daysInMonth + firstWeekday - 1;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                  _loadMonthlyData(_focusedDay);
                });
              },
            ),
            Text(
              DateFormat('yyyy年MM月').format(_focusedDay),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                  _loadMonthlyData(_focusedDay);
                });
              },
            ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 1.0,
            mainAxisSpacing: 1.0,
            childAspectRatio: 1,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            final dayOffset = firstWeekday - 1;
            final day = index - dayOffset + 1;
            if (index < dayOffset || day > daysInMonth) {
              return const SizedBox.shrink();
            }
            final currentDate = DateTime(_focusedDay.year, _focusedDay.month, day);
            final isToday = currentDate.year == DateTime.now().year &&
                currentDate.month == DateTime.now().month &&
                currentDate.day == DateTime.now().day;
            final isSelected = _selectedDay != null &&
                currentDate.year == _selectedDay!.year &&
                currentDate.month == _selectedDay!.month &&
                currentDate.day == _selectedDay!.day;
            final dailyTransactions = _transactionsByDate[currentDate] ?? [];
            final dailyIncome = dailyTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
            final dailyExpense = dailyTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
            return GestureDetector(
              onTap: () => _onDaySelected(currentDate),
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isToday ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                  border: isSelected
                      ? Border.all(color: Colors.blueAccent, width: 2)
                      : Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday ? Colors.blue : Colors.black,
                        )),
                    if (dailyIncome > 0)
                      Text('+${dailyIncome.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 10)),
                    if (dailyExpense > 0)
                      Text('-${dailyExpense.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontSize: 10)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTableSection() {
    if (_selectedDayTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _selectedDay == null
                ? '日付を選択してください'
                : '${DateFormat('yyyy/MM/dd').format(_selectedDay!)} のデータはありません',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildHeaderCell('タイプ'),
              _buildHeaderCell('金額'),
              _buildHeaderCell('タグ'),
              _buildHeaderCell('メモ'),
            ],
          ),
          const Divider(height: 1),
          SizedBox(
            height: 300,
            width: 600,
            child: ListView.builder(
              itemCount: _selectedDayTransactions.length,
              itemBuilder: (context, index) {
                final t = _selectedDayTransactions[index];
                return Row(
                  children: [
                    _buildDataCell(
                      t.type == 'income' ? '収入' : '支出',
                      color: t.type == 'income'
                          ? Colors.lightGreen[400]
                          : Colors.red[300],
                    ),
                    _buildDataCell('${t.amount.toStringAsFixed(0)}円'),
                    _buildDataCell(t.tag),
                    _buildDataCell(t.memo ?? ''),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDataCell(String text, {Color? color}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}
