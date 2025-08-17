import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';            // ← 追加: TextInputFormatter
import 'package:characters/characters.dart';       // ← 追加: 安全な文字数カウント
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

/// メモ入力を 50 文字で打ち止めし、超過トライ時にスナックバーを出すフォーマッタ
class _MemoLimitFormatter extends TextInputFormatter {
  _MemoLimitFormatter({required this.max, required this.onLimit});

  final int max;
  final VoidCallback onLimit;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Characters を使ってサロゲートペア・結合文字にも安全に対応
    final len = newValue.text.characters.length;
    if (len <= max) return newValue;

    onLimit();

    final truncated = newValue.text.characters.take(max).toString();
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
      composing: TextRange.empty,
    );
  }
}

class _QuickInputModalState extends State<QuickInputModal> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // ▼ 初期展開サイズを実測で決めるための状態
  final GlobalKey _preGridKey = GlobalKey();
  double? _preGridHeight; // 電卓より上の実測高さ（シート内パディング含む）
  static const double _horizontalPadding = 32.0; // 左右 16 + 16
  static const double _snackReserve = 100.0; // 電卓下に空ける余白（スナックバー用）
  static const double _minChildSize = 0.5;
  static const double _maxChildSize = 1.0;

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

  // --- スナックバー ---
  void _showSnackBar(String message) {
    _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- 電卓入力 ---
  void _onNumberPressed(String number) {
    setState(() {
      if (_amountString == '0') {
        _amountString = number;
      } else {
        final newAmountString = _amountString + number;
        final newAmount = int.tryParse(newAmountString);
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
      setState(() => _selectedDate = picked);
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
    if (widget.initialTransaction?.id != null &&
        widget.initialTransaction!.type == _transactionType) {
      existingAmount = widget.initialTransaction!.amount;
    }

    if ((currentMonthTotal - existingAmount + amount) >
        AppConstants.MAX_MONTHLY_AMOUNT) {
      _showSnackBar(
          'この月の${_transactionType == "expense" ? "支出" : "収入"}が${Formatter.formatAmount(AppConstants.MAX_MONTHLY_AMOUNT)}円を超えます。');
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
    if (mounted) Navigator.of(context).pop();
  }

  // --- 電卓（Grid）の高さを画面幅から厳密算出 ---
  double _computeGridHeight(double availableWidth) {
    const crossAxisCount = 3;
    const crossAxisSpacing = 4.0;
    const mainAxisSpacing = 4.0;
    const childAspectRatio = 2.4; // width / height
    const itemCount = 12;
    final rows = (itemCount / crossAxisCount).ceil(); // 4

    final itemWidth =
        (availableWidth - (crossAxisCount - 1) * crossAxisSpacing) /
            crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;
    return rows * itemHeight + (rows - 1) * mainAxisSpacing;
  }

  // --- 初期サイズ（fraction）を実測から計算 ---
  double _computeInitialSize(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final availableWidth =
        MediaQuery.of(context).size.width - _horizontalPadding;

    final gridHeight = _computeGridHeight(availableWidth);
    // preGridHeight がまだ取れていなければ仮値（初回ビルド時、すぐ更新されます）
    final pre = _preGridHeight ?? 360.0;

    final desiredHeight = pre + gridHeight + _snackReserve;
    final fraction =
        (desiredHeight / screenHeight).clamp(_minChildSize, _maxChildSize);
    return fraction;
  }

  @override
  Widget build(BuildContext context) {
    final transactionViewModel = Provider.of<TransactionViewModel>(context);
    final settingsViewModel = Provider.of<SettingsViewModel>(context);
    final allTags = transactionViewModel.getTagsByType(_transactionType);

    if (allTags.isEmpty || !allTags.any((t) => t.name == '未設定')) {
      return const Center(child: CircularProgressIndicator());
    }

    final defaultTagNames = _transactionType == 'income'
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

    final initialSize = _computeInitialSize(context);

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: _minChildSize,
        maxChildSize: _maxChildSize, // ユーザーは必要なら全画面まで拡張可
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
                    // --- シートハンドル ---
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
                    // --- ここから「電卓より上」をひとかたまりで実測 ---
                    _MeasureSize(
                      key: _preGridKey,
                      onChange: (size) {
                        if (size == null) return;
                        final h = size.height;
                        if (h != _preGridHeight) {
                          setState(() => _preGridHeight = h);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 日付行
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_left),
                                onPressed: () => setState(() => _selectedDate =
                                    _selectedDate
                                        .subtract(const Duration(days: 1))),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _selectDate(context),
                                  child: Text(
                                    DateFormat('yyyy年MM月dd日')
                                        .format(_selectedDate),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_right),
                                onPressed: () => setState(() => _selectedDate =
                                    _selectedDate
                                        .add(const Duration(days: 1))),
                              ),
                            ],
                          ),
                          // タイプ切替 ＋ 金額表示
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 68,
                                height: 60,
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
                                  final isExpense =
                                      _transactionType == 'expense';
                                  final itemHeight =
                                      (constraints.maxHeight / 2) - 2;
                                  return Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Stack(
                                      children: [
                                        AnimatedPositioned(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          curve: Curves.easeInOut,
                                          top: isExpense
                                              ? 0
                                              : itemHeight + 2,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: itemHeight,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6.0),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset:
                                                      const Offset(0, 2),
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _transactionType =
                                                        'expense';
                                                    _selectedTag = '未設定';
                                                  });
                                                },
                                                child: Center(
                                                  child: Text(
                                                    '支出',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isExpense
                                                          ? Colors.black
                                                          : Colors
                                                              .grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _transactionType =
                                                        'income';
                                                    _selectedTag = '未設定';
                                                  });
                                                },
                                                child: Center(
                                                  child: Text(
                                                    '収入',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: !isExpense
                                                          ? Colors.black
                                                          : Colors
                                                              .grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 5),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${Formatter.formatAmount(int.tryParse(_amountString) ?? 0)}円',
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // タグ
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 8),
                                padding:
                                    const EdgeInsets.fromLTRB(8, 16, 8, 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value:
                                          isTagInDropdown ? _selectedTag : null,
                                      isExpanded: true,
                                      items: dropdownTags.map((Tag tag) {
                                        return DropdownMenuItem<String>(
                                          value: tag.name,
                                          child: Text(tag.name,
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedTag =
                                              newValue ?? '未設定';
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 4),
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: defaultTags.map((tag) {
                                        return ChoiceChip(
                                          label: Text(tag.name,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          selected:
                                              _selectedTag == tag.name,
                                          onSelected: (selected) {
                                            setState(() {
                                              _selectedTag = selected
                                                  ? tag.name
                                                  : '未設定';
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  color: Theme.of(context)
                                      .scaffoldBackgroundColor,
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
                          // メモ（50文字制限 + 超過時はスナックバー）
                          TextField(
                            controller: _memoController,
                            decoration: const InputDecoration(
                              labelText: 'メモ (任意)',
                              border: OutlineInputBorder(),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                            ),
                            maxLines: 1,
                            inputFormatters: [
                              _MemoLimitFormatter(
                                max: 50,
                                onLimit: () => _showSnackBar('メモは50文字までです。'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    // --- ここから電卓（Grid） ---
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
                        final keys = ['1','2','3','4','5','6','7','8','9','','0','✓'];
                        final key = keys[index];
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
                            child:
                                const Icon(Icons.check, color: Colors.white),
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
                            onPressed: () => _onNumberPressed(key),
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
                    // ▼ 電卓の下にだけ、スナックバーぶんの余白を確保（開き過ぎ防止は initialChildSize 側で調整）
                    const SizedBox(height: _snackReserve),
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

/// 子ウィジェットの表示サイズを取得するためのユーティリティ
class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size?> onChange;
  const _MeasureSize({super.key, required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contextBox = context.findRenderObject();
      if (contextBox is RenderBox) {
        final newSize = contextBox.size;
        if (_oldSize == null || _oldSize != newSize) {
          _oldSize = newSize;
          widget.onChange(newSize);
        }
      }
    });
    return widget.child;
  }
}
