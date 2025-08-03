import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentNumber = '0';

  final _memoController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'expense';
  String _selectedTag = '未設定';

  final List<String> _expenseTags = [
    '未設定', '食費', '交通費', '娯楽費', '日用品', '家賃', '光熱費', '通信費', '医療費', '教育費', 'その他'
  ];
  final List<String> _incomeTags = [
    '未設定', '給与', '副業', '臨時収入', 'その他'
  ];

  List<String> get _currentTags =>
      _selectedType == 'expense' ? _expenseTags : _incomeTags;

  @override
  void initState() {
    super.initState();
    _selectedTag = _currentTags.first;
  }

  void _onCalculatorButtonPressed(String buttonText) {
    setState(() {
      if (buttonText == 'AC') {
        _currentNumber = '0';
      } else if (buttonText == '.') {
        if (!_currentNumber.contains('.')) {
          _currentNumber += '.';
        }
      } else {
        if (_currentNumber == '0' && buttonText != '.') {
          _currentNumber = buttonText;
        } else {
          _currentNumber += buttonText;
        }
      }
    });
  }

  Widget _buildCalculatorButton(String buttonText,
      {Color? color, Color? textColor, Widget? icon}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: () => _onCalculatorButtonPressed(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey[300],
            minimumSize: const Size(80, 80),
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: icon ??
              Text(
                buttonText,
                style: TextStyle(fontSize: 24, color: textColor ?? Colors.black),
              ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() async {
    if (_currentNumber == '0' || _currentNumber == 'Error' || _currentNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金額を入力してください')),
      );
      return;
    }

    final amount = double.tryParse(_currentNumber);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('有効な金額を入力してください')),
      );
      return;
    }

    final newTransaction = Transaction(
      date: _selectedDate,
      amount: amount,
      type: _selectedType,
      tag: _selectedTag,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
    );

    await Provider.of<TransactionViewModel>(context, listen: false)
        .addTransaction(newTransaction);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存しました！')),
    );

    _memoController.clear();
    setState(() {
      _currentNumber = '0';
      _selectedDate = DateTime.now();
      _selectedType = 'expense';
      _selectedTag = _currentTags.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateController = TextEditingController(
      text: DateFormat('yyyy/MM/dd').format(_selectedDate),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 収入/支出トグル
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedType = 'income';
                          _selectedTag = _currentTags.first;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == 'income'
                            ? Colors.green
                            : Colors.grey[300],
                        foregroundColor: _selectedType == 'income'
                            ? Colors.white
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.horizontal(left: Radius.circular(8.0)),
                        ),
                      ),
                      child: const Text('収入', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedType = 'expense';
                          _selectedTag = _currentTags.first;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedType == 'expense'
                            ? Colors.red[300]
                            : Colors.grey[300],
                        foregroundColor: _selectedType == 'expense'
                            ? Colors.white
                            : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.horizontal(right: Radius.circular(8.0)),
                        ),
                      ),
                      child: const Text('支出', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 日付 + タグ（高さ揃える）
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      controller: dateController,
                      onTap: () => _selectDate(context),
                      decoration: const InputDecoration(
                        labelText: '日付',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedTag,
                      decoration: const InputDecoration(
                        labelText: 'タグ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                      items: _currentTags.map((String tag) {
                        return DropdownMenuItem<String>(
                          value: tag,
                          child: Text(tag),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTag = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // メモ
              TextField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: 'メモ (任意)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12), // 高さを調整
                  isDense: true, // 高さをよりコンパクトに
                ),
                maxLines: 1,
                minLines: 1,
              ),
              const SizedBox(height: 20),

              // 金額表示
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _currentNumber,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),

              // 電卓UI
              Column(
                children: [
                  Row(children: [
                    _buildCalculatorButton('7'),
                    _buildCalculatorButton('8'),
                    _buildCalculatorButton('9'),
                  ]),
                  Row(children: [
                    _buildCalculatorButton('4'),
                    _buildCalculatorButton('5'),
                    _buildCalculatorButton('6'),
                  ]),
                  Row(children: [
                    _buildCalculatorButton('1'),
                    _buildCalculatorButton('2'),
                    _buildCalculatorButton('3'),
                  ]),
                  Row(children: [
                    _buildCalculatorButton('AC', color: Colors.orange, textColor: Colors.white),
                    _buildCalculatorButton('0'),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ElevatedButton(
                          onPressed: _saveTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            minimumSize: const Size(80, 80),
                            padding: const EdgeInsets.all(20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
