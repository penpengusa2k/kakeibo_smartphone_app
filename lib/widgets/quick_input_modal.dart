import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/viewmodels/settings_viewmodel.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/utils/app_constants.dart';
import 'package:kakeibo_smartphone_app/models/tag.dart';

class QuickInputModal extends StatefulWidget {
  final Transaction? initialTransaction;
  final DateTime? initialDate;
  final Function(Transaction) onSave;
  final Function(int)? onDelete;

  const QuickInputModal({
    super.key,
    this.initialTransaction,
    this.initialDate,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<QuickInputModal> createState() => _QuickInputModalState();
}

class _QuickInputModalState extends State<QuickInputModal> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  String _amountString = '0';
  String _transactionType = 'expense';
  DateTime _selectedDate = DateTime.now();
  String _selectedTag = '未設定';
  final TextEditingController _memoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      _amountString = widget.initialTransaction!.amount.toString();
      _transactionType = widget.initialTransaction!.type;
      _selectedDate = widget.initialTransaction!.date;
      _selectedTag = widget.initialTransaction!.tag;
      _memoController.text = widget.initialTransaction!.memo ?? '';
    } else if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_amountString == '0') {
        _amountString = number;
      } else {
        String newAmountString = _amountString + number;
        int? newAmount = int.tryParse(newAmountString);
        if (newAmount == null || newAmount > AppConstants.MAX_AMOUNT) {
          _showSnackBar('入力上限を超えています。');
          return;
        }
        _amountString = newAmountString;
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_amountString.length > 1) {
        _amountString = _amountString.substring(0, _amountString.length - 1);
      } else {
        _amountString = '0';
      }
    });
  }

  void _onClearPressed() {
    setState(() {
      _amountString = '0';
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    final transactionViewModel =
        Provider.of<TransactionViewModel>(context, listen: false);
    final int? amount = int.tryParse(_amountString);

    if (amount == null || amount <= 0) {
      _showSnackBar('金額を正しく入力してください。');
      return;
    }

    if (amount > AppConstants.MAX_AMOUNT) {
      _showSnackBar('入力上限を超えています。');
      return;
    }

    final currentMonthTotal = await transactionViewModel.getMonthlyTotalAmount(
      _selectedDate.year,
      _selectedDate.month,
      _transactionType,
    );

    int existingAmount = 0;
    if (widget.initialTransaction != null &&
        widget.initialTransaction!.id != null) {
      if (widget.initialTransaction!.type == _transactionType) {
        existingAmount = widget.initialTransaction!.amount;
      }
    }

    if ((currentMonthTotal - existingAmount + amount) >
        AppConstants.MAX_MONTHLY_AMOUNT) {
      _showSnackBar(
          'この月の${_transactionType == 'expense' ? '支出' : '収入'}が${Formatter.formatAmount(AppConstants.MAX_MONTHLY_AMOUNT)}円を超えます。');
      return;
    }

    final transaction = Transaction(
      id: widget.initialTransaction?.id,
      amount: amount,
      type: _transactionType,
      date: _selectedDate,
      tag: _selectedTag,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
    );
    await widget.onSave(transaction);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final settingsViewModel = Provider.of<SettingsViewModel>(context);
    final allTags = transactionViewModel.getTagsByType(_transactionType);

    if (allTags.isEmpty || !allTags.any((t) => t.name == '未設定')) {
      return const Center(child: CircularProgressIndicator());
    }

    List<String> defaultTagNames = _transactionType == 'income'
        ? settingsViewModel.appSettings?.defaultIncomeTags ?? []
        : settingsViewModel.appSettings?.defaultExpenseTags ?? [];

    final defaultTags = defaultTagNames
        .where((tagName) => allTags.any((tag) => tag.name == tagName))
        .map((tagName) => allTags.firstWhere((tag) => tag.name == tagName))
        .toList();

    final dropdownTags = [
      allTags.firstWhere((t) => t.name == '未設定'),
      ...allTags.where((t) => t.name != '未設定')
    ];
    final isTagInDropdown = dropdownTags.any((tag) => tag.name == _selectedTag);

    // Calculate initial sheet size to fit content up to the calculator.
    // This prevents the sheet from opening too high on tall screens.
    const double contentHeight = 680; // Estimated content height in pixels.
    final screenHeight = MediaQuery.of(context).size.height;
    final double initialSize = (contentHeight / screenHeight).clamp(0.5, 0.9);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: 0.5,
        maxChildSize: 1.0, // 画面全体に拡張できるように変更
        expand: false,
        builder: (context, scrollController) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // スクロール可能なことを示すインジケーター
                    Center(
                      child: Container(
                        height: 5,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_left),
                          onPressed: () => setState(() => _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1))),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Text(
                              DateFormat('yyyy年MM月dd日').format(_selectedDate),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_right),
                          onPressed: () => setState(() => _selectedDate =
                              _selectedDate.add(const Duration(days: 1))),
                        ),
                      ],
                    ),
                    // const SizedBox(height: 4),
                    Center(
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: _transactionType,
                        onValueChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _transactionType = value;
                              _selectedTag = '未設定';
                            });
                          }
                        },
                        children: const <String, Widget>{
                          'expense': Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text('支出'),
                          ),
                          'income': Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Text('収入'),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${Formatter.formatAmount(
                                int.tryParse(_amountString) ?? 0)}円',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // const SizedBox(height: 2),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: isTagInDropdown ? _selectedTag : null,
                                isExpanded: true,
                                items: dropdownTags.map((Tag tag) {
                                  return DropdownMenuItem<String>(
                                    value: tag.name,
                                    child: Text(tag.name, style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedTag = newValue ?? '未設定';
                                  });
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                ),
                              ),
                              // const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: defaultTags.map((tag) {
                                  return ChoiceChip(
                                    label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                                    selected: _selectedTag == tag.name,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTag =
                                            selected ? tag.name : '未設定';
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: Text(
                              'タグ',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _memoController,
                      decoration: const InputDecoration(
                        labelText: 'メモ (任意)',
                        border: OutlineInputBorder(),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.4,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final List<String> keys = [
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                          '',
                          '0',
                          '✓',
                        ];
                        final String key = keys[index];

                        if (key == '✓') {
                          return ElevatedButton(
                            onPressed: _saveTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Icon(Icons.check, color: Colors.white),
                          );
                        } else if (index == 9) {
                          return ElevatedButton(
                            onPressed: _onBackspacePressed,
                            onLongPress: _onClearPressed,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Icon(Icons.backspace_outlined),
                          );
                        } else {
                          return ElevatedButton(
                            onPressed: () {
                              _onNumberPressed(key);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(fontSize: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(key),
                          );
                        }
                      },
                    ),
                    // Add space below the calculator to prevent snackbar overlap
                    const SizedBox(height: 100.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
