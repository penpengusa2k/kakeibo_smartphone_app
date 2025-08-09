import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/viewmodels/settings_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/widgets/quick_input_modal.dart';
import 'package:flutter/cupertino.dart'; // CupertinoPickerのために追加

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Transaction> _selectedDayTransactions = [];
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _pageController = PageController(initialPage: 9999);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedDayTransactions();
  }

  void _onDaySelected(DateTime selectedDay) {
    setState(() {
      _selectedDay = selectedDay;
    });
    _updateSelectedDayTransactions();
  }

  void _updateSelectedDayTransactions() {
    final transactionViewModel = Provider.of<TransactionViewModel>(context, listen: false);
    if (_selectedDay == null) {
      _selectedDayTransactions = [];
      return;
    }
    _selectedDayTransactions = transactionViewModel.transactions
        .where((t) =>
            t.date.year == _selectedDay!.year &&
            t.date.month == _selectedDay!.month &&
            t.date.day == _selectedDay!.day)
        .toList();
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _focusedDay.year;
    int selectedMonth = _focusedDay.month;

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
                    scrollController: FixedExtentScrollController(initialItem: selectedYear - 2000),
                    itemExtent: 40.0, // UI調整
                    onSelectedItemChanged: (int index) {
                      selectedYear = 2000 + index;
                    },
                    children: List<Widget>.generate(now.year - 2000 + 2, (int index) { // 来年まで表示
                      return Center(child: Text('${2000 + index}年', style: const TextStyle(fontSize: 20)));
                    }),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: selectedMonth - 1),
                    itemExtent: 40.0, // UI調整
                    onSelectedItemChanged: (int index) {
                      selectedMonth = index + 1;
                    },
                    children: List<Widget>.generate(12, (int index) {
                      return Center(child: Text('${index + 1}月', style: const TextStyle(fontSize: 20)));
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
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
        // pickedDateは既に日付が1日になっているので、そのまま使用
        final newDate = pickedDate;
        
        // 元の_focusedDayと異なる場合にのみ更新
        if (newDate.year != _focusedDay.year || newDate.month != _focusedDay.month) {
            setState(() {
                _focusedDay = newDate;
                final newPageIndex = 9999 + (_focusedDay.year - now.year) * 12 + (_focusedDay.month - now.month);
                _pageController.jumpToPage(newPageIndex);
                _selectedDay = null; // 日付選択をリセット
            });
            _updateSelectedDayTransactions();
        }
      }
    });
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

    final now = DateTime.now();
    final oneYearLater = DateTime(now.year + 1, now.month, 1);
    final isNextDisabled = _focusedDay.year == oneYearLater.year && _focusedDay.month == oneYearLater.month;

    return Scaffold(
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Column(
              children: [
                // カレンダーのWidgetを先に配置
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: () => _selectMonth(context),
                        child: Text(
                          DateFormat('yyyy年MM月').format(_focusedDay),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      isNextDisabled
                        ? const SizedBox(width: 48.0) // IconButtonのスペースを確保
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _focusedDay = DateTime(
                          DateTime.now().year,
                          DateTime.now().month + (index - 9999),
                          1,
                        );
                        _selectedDay = null;
                        _updateSelectedDayTransactions();
                      });
                    },
                    itemBuilder: (context, pageIndex) {
                      final currentMonth = DateTime(
                        DateTime.now().year,
                        DateTime.now().month + (pageIndex - 9999),
                        1,
                      );
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['日', '月', '火', '水', '木', '金', '土']
                                .map((day) => Text(day, style: const TextStyle(fontWeight: FontWeight.bold)))
                                .toList(),
                          ),
                          const Divider(),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                              itemCount: DateTime(currentMonth.year, currentMonth.month + 1, 0).day +
                                  (DateTime(currentMonth.year, currentMonth.month, 1).weekday % 7),
                              itemBuilder: (context, index) {
                                final firstDayWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday % 7;
                                if (index < firstDayWeekday) {
                                  return Container();
                                }
                                final day = index - firstDayWeekday + 1;
                                final date = DateTime(currentMonth.year, currentMonth.month, day);

                                final isSelected = _selectedDay != null &&
                                    _selectedDay!.year == date.year &&
                                    _selectedDay!.month == date.month &&
                                    _selectedDay!.day == date.day;

                                int dayIncome = 0;
                                int dayExpense = 0;
                                final dayTransactions = transactionViewModel.transactions.where((t) =>
                                        t.date.year == date.year &&
                                        t.date.month == date.month &&
                                        t.date.day == date.day);
                                for (var t in dayTransactions) {
                                  if (t.type == 'income') {
                                    dayIncome += t.amount;
                                  } else {
                                    dayExpense += t.amount;
                                  }
                                }

                                final now = DateTime.now();
                                final isToday = now.year == date.year &&
                                    now.month == date.month &&
                                    now.day == date.day;

                                return GestureDetector(
                                  onTap: () => _onDaySelected(date),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: isToday
                                          ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                          : Border.all(color: Colors.grey.shade300),
                                      color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.white,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
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
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                // サマリーのWidgetを次に配置
                Card(
                  margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
                  color: Colors.grey.shade200,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
                // 選択された日の取引リストのWidgetを最後に配置
                Expanded(
                  flex: 4,
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
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('タグ: ${transaction.tag}'),
                                      if (transaction.memo != null && transaction.memo!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text('メモ: ${transaction.memo!}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ),
                                    ],
                                  ),
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
          ),
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
