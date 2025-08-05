
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/viewmodels/settings_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/widgets/quick_input_modal.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Transaction> _selectedDayTransactions = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedDayTransactions();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _updateSelectedDayTransactions();
  }

  void _updateSelectedDayTransactions() {
    final transactionViewModel = Provider.of<TransactionViewModel>(context, listen: false);
    _selectedDayTransactions = transactionViewModel.transactions
        .where((t) =>
            t.date.year == _selectedDay!.year &&
            t.date.month == _selectedDay!.month &&
            t.date.day == _selectedDay!.day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final settingsViewModel = Provider.of<SettingsViewModel>(context);

    int totalIncome = 0;
    int totalExpense = 0;
    final currentMonthTransactions = transactionViewModel.transactions.where((t) =>
        t.date.year == _focusedDay.year && t.date.month == _focusedDay.month);
    for (var t in currentMonthTransactions) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    int monthlyBalance = totalIncome - totalExpense;

    final monthlyBudget = settingsViewModel.appSettings?.monthlyBudget ?? 0;
    double budgetProgress = 0.0;
    if (monthlyBudget > 0) {
      budgetProgress = totalExpense / monthlyBudget;
      if (budgetProgress > 1.0) budgetProgress = 1.0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('yyyy年MM月').format(_focusedDay)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, _focusedDay.day);
              _updateSelectedDayTransactions();
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, _focusedDay.day);
                _updateSelectedDayTransactions();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('収入', totalIncome, Colors.green),
                      _buildSummaryItem('支出', totalExpense, Colors.red),
                      _buildSummaryItem('収支', monthlyBalance, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  if (monthlyBudget > 0) ...[
                    LinearProgressIndicator(
                      value: budgetProgress,
                      backgroundColor: Colors.grey[300],
                      color: budgetProgress > 0.8 ? Colors.red : Colors.blue,
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      '月間予算: ${Formatter.formatAmount(monthlyBudget)}円 (残り: ${Formatter.formatAmount(monthlyBudget - totalExpense)}円)',
                      style: const TextStyle(fontSize: 12.0),
                    ),
                  ]
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemCount: 30,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = _selectedDay?.day == day && _selectedDay?.month == _focusedDay.month;
                int dayIncome = 0;
                int dayExpense = 0;
                final dayTransactions = transactionViewModel.transactions.where((t) =>
                    t.date.year == _focusedDay.year &&
                    t.date.month == _focusedDay.month &&
                    t.date.day == day);
                for (var t in dayTransactions) {
                  if (t.type == 'income') {
                    dayIncome += t.amount;
                  } else {
                    dayExpense += t.amount;
                  }
                }

                final now = DateTime.now();
                final isToday = now.year == _focusedDay.year &&
                    now.month == _focusedDay.month &&
                    now.day == day;

                return GestureDetector(
                  onTap: () => _onDaySelected(DateTime(_focusedDay.year, _focusedDay.month, day), _focusedDay),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isToday
                          ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                          : Border.all(color: Colors.grey.shade300),
                      color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.white,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
                        ),
                        if (dayIncome > 0) FittedBox(child: Text(Formatter.formatAmount(dayIncome), style: const TextStyle(color: Colors.green, fontSize: 10))),
                        if (dayExpense > 0) FittedBox(child: Text(Formatter.formatAmount(dayExpense), style: const TextStyle(color: Colors.red, fontSize: 10))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _selectedDayTransactions.isEmpty
                ? const Center(child: Text('選択した日付の取引はありません。'))
                : ListView.builder(
                    itemCount: _selectedDayTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _selectedDayTransactions[index];
                      return Dismissible(
                        key: Key(transaction.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("確認"),
                                content: Text("'${transaction.tag}'の取引を削除してもよろしいですか？"),
                                actions: <Widget>[
                                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("キャンセル")),
                                  TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("削除")),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) async {
                          await transactionViewModel.deleteTransaction(transaction.id!);
                          _updateSelectedDayTransactions();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${transaction.tag}の取引を削除しました')),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: ListTile(
                            leading: Icon(
                              transaction.type == 'income' ? Icons.add_circle : Icons.remove_circle,
                              color: transaction.type == 'income' ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              '${Formatter.formatAmount(transaction.amount)}円',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: transaction.type == 'income' ? Colors.green : Colors.red,
                              ),
                            ),
                            subtitle: Text('${transaction.tag} - ${transaction.memo ?? ''}'),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                useSafeArea: true,
                                enableDrag: false,
                                builder: (context) => Material(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: QuickInputModal(
                                    initialTransaction: transaction,
                                    onSave: (updatedTransaction) async {
                                      await transactionViewModel.updateTransaction(updatedTransaction);
                                      _updateSelectedDayTransactions();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => QuickInputModal(
    initialDate: _selectedDay,
    onSave: (newTransaction) async {
      await transactionViewModel.addTransaction(newTransaction);
      _updateSelectedDayTransactions();
      
    },
  ),
);
        },
        child: const Icon(Icons.add),
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
