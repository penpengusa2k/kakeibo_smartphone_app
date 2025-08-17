import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/viewmodels/settings_viewmodel.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/widgets/quick_input_modal.dart';

/// ───────── sizing / colors ─────────
const double kCalendarFixedHeight = 240;
const double kWeekdayRowHeight = 20.0;
const double kWeekdayDividerH = 6.0;
const double kWeekdayFontSize = 10;
const double kDayNumberFontSize = 10;
const double kDayHeaderHeight = 12;

const Color kBandBgColor = Color(0xFFF2F3F5);

const double kTableHeaderMinH = 30;
const double kTableHeaderMaxH = 34;
const double kDateHeaderMinH = 28;
const double kDateHeaderMaxH = 32;

const double kTxRowHeight = 44;

const double kSummaryTileHeight = 56;
const double kSummaryAmountLineHeight = 22;
const double kSummaryLabelFontSize = 12;
const double kSummaryAmountFontSize = 14;

/// ───────── page ─────────
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late PageController _pageController;

  bool _showSwipeHint = true;
  bool _userInteracted = false;

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

  void _onDaySelected(DateTime selectedDay) {
    setState(() => _selectedDay = selectedDay);
  }

  Future<void> _selectMonth(BuildContext context) async {
    final now = DateTime.now();
    int selectedYear = _focusedDay.year;
    int selectedMonth = _focusedDay.month;

    await showDialog(
      context: context,
      builder: (_) {
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
                    itemExtent: 40.0,
                    onSelectedItemChanged: (i) => selectedYear = 2000 + i,
                    children: List<Widget>.generate(
                      now.year - 2000 + 2,
                      (i) => Center(child: Text('${2000 + i}年', style: const TextStyle(fontSize: 20))),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: selectedMonth - 1),
                    itemExtent: 40.0,
                    onSelectedItemChanged: (i) => selectedMonth = i + 1,
                    children: List<Widget>.generate(
                      12,
                      (i) => Center(child: Text('${i + 1}月', style: const TextStyle(fontSize: 20))),
                    ),
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
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
            TextButton(
              onPressed: () {
                final oneYearLater = DateTime(now.year + 1, now.month, 1);
                final picked = DateTime(selectedYear, selectedMonth);
                if (picked.isAfter(oneYearLater)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('1年後より未来の月は選択できません')),
                  );
                  return;
                }
                Navigator.of(context).pop(picked);
              },
              child: const Text('決定'),
            ),
          ],
        );
      },
    ).then((pickedDate) {
      if (pickedDate is DateTime) {
        final newDate = pickedDate;
        if (newDate.year != _focusedDay.year || newDate.month != _focusedDay.month) {
          setState(() {
            _focusedDay = newDate;
            final base = DateTime.now();
            final newPageIndex = 9999 + (_focusedDay.year - base.year) * 12 + (_focusedDay.month - base.month);
            _pageController.jumpToPage(newPageIndex);
            _selectedDay = null;
          });
        }
      }
    });
  }

  int _rowsInMonth(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month, 1).weekday % 7; // 0:日
    return ((offset + days) / 7).ceil(); // 5 or 6
  }

  Map<DateTime, List<Transaction>> _groupMonthlyByDay(List<Transaction> all, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final filtered = all.where((t) => !t.date.isBefore(start) && !t.date.isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final map = <DateTime, List<Transaction>>{};
    for (final t in filtered) {
      final key = DateTime(t.date.year, t.date.month, t.date.day);
      (map[key] ??= []).add(t);
    }
    return map;
  }

  // ロケール初期化不要の日本語表記（MM月dd日（火））
  String _formatJPDate(DateTime d) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    final dow = w[d.weekday - 1];
    return '${DateFormat('MM月dd日').format(d)}（$dow）';
  }

  @override
  Widget build(BuildContext context) {
    final txVm = Provider.of<TransactionViewModel>(context);
    final settingsVm = Provider.of<SettingsViewModel>(context);

    int totalIncome = 0;
    int totalExpense = 0;
    final monthlyTx = txVm.transactions.where(
      (t) => t.date.year == _focusedDay.year && t.date.month == _focusedDay.month,
    );
    for (var t in monthlyTx) {
      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    final int monthlyBalance = totalIncome - totalExpense;

    final monthlyBudget = settingsVm.appSettings?.monthlyBudget ?? 0;
    double budgetProgress = 0.0;
    if (monthlyBudget > 0) {
      budgetProgress = totalExpense / monthlyBudget;
      if (budgetProgress > 1.0) budgetProgress = 1.0;
    }

    final grouped = _groupMonthlyByDay(txVm.transactions, _focusedDay);
    final sectionDates = grouped.keys.toList()..sort((a, b) => a.compareTo(b));

    final dividerColor = Colors.grey.shade300;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Column(
            children: [
              // 月タイトル
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 2),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _selectMonth(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Opacity(opacity: 0, child: Icon(Icons.arrow_drop_down)),
                        Text(
                          DateFormat('yyyy年MM月').format(_focusedDay),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),

              // カレンダー
              SizedBox(
                height: kCalendarFixedHeight,
                child: Listener(
                  onPointerDown: (_) {
                    if (!_userInteracted) {
                      setState(() {
                        _userInteracted = true;
                        _showSwipeHint = false;
                      });
                    }
                  },
                  child: LayoutBuilder(
                    builder: (context, cons) {
                      final gridH = (kCalendarFixedHeight - kWeekdayRowHeight - kWeekdayDividerH)
                          .clamp(60.0, 10000.0);

                      return Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _focusedDay = DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month + (index - 9999),
                                  1,
                                );
                                _selectedDay = null;
                                _userInteracted = true;
                                _showSwipeHint = false;
                              });
                            },
                            itemBuilder: (context, pageIndex) {
                              final currentMonth = DateTime(
                                DateTime.now().year,
                                DateTime.now().month + (pageIndex - 9999),
                                1,
                              );

                              final rows = _rowsInMonth(currentMonth);
                              final cellH = gridH / rows;
                              final cellW = cons.maxWidth / 7.0;
                              final dynamicAspect = cellW / cellH;

                              return Column(
                                children: [
                                  SizedBox(
                                    height: kWeekdayRowHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: List.generate(7, (i) {
                                          const labels = ['日', '月', '火', '水', '木', '金', '土'];
                                          final c = i == 0 ? Colors.red : (i == 6 ? Colors.blue : null);
                                          return Text(
                                            labels[i],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: kWeekdayFontSize,
                                              color: c,
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                  const Divider(height: kWeekdayDividerH),

                                  Expanded(
                                    child: GridView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        childAspectRatio: dynamicAspect,
                                      ),
                                      itemCount: DateTime(currentMonth.year, currentMonth.month + 1, 0).day +
                                          (DateTime(currentMonth.year, currentMonth.month, 1).weekday % 7),
                                      itemBuilder: (context, index) {
                                        final firstDayWeekday =
                                            DateTime(currentMonth.year, currentMonth.month, 1).weekday % 7;
                                        if (index < firstDayWeekday) return const SizedBox.shrink();

                                        final day = index - firstDayWeekday + 1;
                                        final date = DateTime(currentMonth.year, currentMonth.month, day);

                                        final isSelected = _selectedDay != null &&
                                            _selectedDay!.year == date.year &&
                                            _selectedDay!.month == date.month &&
                                            _selectedDay!.day == date.day;

                                        int dayIncome = 0;
                                        int dayExpense = 0;
                                        final dayTx = txVm.transactions.where((t) =>
                                            t.date.year == date.year &&
                                            t.date.month == date.month &&
                                            t.date.day == date.day);
                                        for (var t in dayTx) {
                                          if (t.type == 'income') {
                                            dayIncome += t.amount;
                                          } else {
                                            dayExpense += t.amount;
                                          }
                                        }

                                        final today = DateTime.now();
                                        final isToday = today.year == date.year &&
                                            today.month == date.month &&
                                            today.day == date.day;

                                        Color dayNumberColor;
                                        if (date.weekday == DateTime.sunday) {
                                          dayNumberColor = Colors.red;
                                        } else if (date.weekday == DateTime.saturday) {
                                          dayNumberColor = Colors.blue;
                                        } else {
                                          dayNumberColor = Colors.black87;
                                        }

                                        Widget amountLine(int value, Color color) => Center(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '${Formatter.formatAmount(value)}円',
                                                  style: TextStyle(color: color, fontSize: 10),
                                                  maxLines: 1,
                                                  softWrap: false,
                                                ),
                                              ),
                                            );

                                        return GestureDetector(
                                          onTap: () => _onDaySelected(date),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: isToday
                                                  ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                                  : Border.all(color: Colors.grey.shade300),
                                              color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white,
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                                            child: Column(
                                              children: [
                                                SizedBox(
                                                  height: kDayHeaderHeight,
                                                  child: Center(
                                                    child: Text(
                                                      '$day',
                                                      style: TextStyle(
                                                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                                        fontSize: kDayNumberFontSize,
                                                        color: dayNumberColor,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (dayIncome > 0 || dayExpense > 0)
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        if (dayIncome > 0) Expanded(child: amountLine(dayIncome, Colors.green)),
                                                        if (dayExpense > 0) Expanded(child: amountLine(dayExpense, Colors.red)),
                                                      ],
                                                    ),
                                                  ),
                                              ],
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
                          if (_showSwipeHint) const _SwipeHintOverlay(),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // サマリ帯
              Container(
                color: kBandBgColor,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: kSummaryTileHeight,
                          child: _SummaryTileFrame(
                            label: '収入',
                            color: Colors.green,
                            icon: Icons.trending_up,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${Formatter.formatAmount(totalIncome)}円',
                                maxLines: 1,
                                softWrap: false,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: const TextStyle(
                                  fontSize: kSummaryAmountFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: kSummaryTileHeight,
                          child: _SummaryTileFrame(
                            label: '支出',
                            color: Colors.red,
                            icon: Icons.trending_down,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${Formatter.formatAmount(totalExpense)}円',
                                maxLines: 1,
                                softWrap: false,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: const TextStyle(
                                  fontSize: kSummaryAmountFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: kSummaryTileHeight,
                          child: _SummaryTileFrame(
                            label: '収支',
                            color: Colors.blue,
                            icon: Icons.stacked_line_chart,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${Formatter.formatAmount(monthlyBalance)}円',
                                maxLines: 1,
                                softWrap: false,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: const TextStyle(
                                  fontSize: kSummaryAmountFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 取引テーブル
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // カラム見出し（パディングはRowだけ／Dividerは全幅）
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SimpleHeaderDelegate(
                        minExtent: kTableHeaderMinH,
                        maxExtent: kTableHeaderMaxH,
                        builder: (context, shrinkOffset, overlapsContent) {
                          return Container(
                            color: kBandBgColor,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: const [
                                      Expanded(
                                        flex: 4,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('タグ',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('メモ',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('金額',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // ← パディング外にDivider（左右端まで）
                                Divider(height: 1, thickness: 1, color: dividerColor),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    if (sectionDates.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('この月の取引はありません。')),
                      )
                    else ...[
                      for (final d in sectionDates)
                        SliverStickyHeader(
                          overlapsContent: false,
                          header: Container(
                            height: kDateHeaderMaxH,
                            color: kBandBgColor,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _formatJPDate(d),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // ← こちらも全幅Divider
                                Divider(height: 1, thickness: 1, color: dividerColor),
                              ],
                            ),
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final t = grouped[d]![index];
                                return _TxRow(
                                  dividerColor: dividerColor,
                                  transaction: t,
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
                                          initialTransaction: t,
                                          onSave: (updated) async {
                                            await txVm.updateTransaction(updated);
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  onDelete: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('確認'),
                                        content: Text("'${t.tag}'の取引を削除してもよろしいですか？"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await txVm.deleteTransaction(t.id!);
                                      setState(() {});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text('${t.tag}の取引を削除しました')));
                                      }
                                    }
                                  },
                                );
                              },
                              childCount: grouped[d]!.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final txVm = Provider.of<TransactionViewModel>(context, listen: false);
          return FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => QuickInputModal(
                  initialDate: _selectedDay,
                  onSave: (newTransaction) async {
                    await txVm.addTransaction(newTransaction);
                    setState(() {});
                  },
                ),
              );
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

/// ヒント
class _SwipeHintOverlay extends StatelessWidget {
  const _SwipeHintOverlay();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// サマリータイル
class _SummaryTileFrame extends StatelessWidget {
  const _SummaryTileFrame({
    required this.label,
    required this.color,
    required this.icon,
    required this.child,
  });
  final String label;
  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tileColor = Theme.of(context).cardColor;
    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: TextStyle(
                        fontSize: kSummaryLabelFontSize,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: kSummaryAmountLineHeight,
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// SliverPersistentHeader delegate
class _SimpleHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SimpleHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
  });
  @override
  final double minExtent;
  @override
  final double maxExtent;

  final Widget Function(BuildContext context, double shrinkOffset, bool overlapsContent) builder;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      builder(context, shrinkOffset, overlapsContent);

  @override
  bool shouldRebuild(covariant _SimpleHeaderDelegate oldDelegate) =>
      minExtent != oldDelegate.minExtent ||
      maxExtent != oldDelegate.maxExtent ||
      builder != oldDelegate.builder;
}

/// 1行（下線あり）
class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
    required this.dividerColor,
  });
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final color = isIncome ? Colors.green : Colors.red;

    return Dismissible(
      key: Key(transaction.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDelete(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: kTxRowHeight,
            child: Material(
              color: Theme.of(context).cardColor,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(isIncome ? Icons.add_circle : Icons.remove_circle, color: color, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Text(
                          transaction.tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Text(
                          (transaction.memo ?? '').isEmpty ? '－' : transaction.memo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isIncome ? '+' : '-'}${Formatter.formatAmount(transaction.amount)}円',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
        ],
      ),
    );
  }
}
