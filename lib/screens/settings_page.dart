import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kakeibo_smartphone_app/viewmodels/settings_viewmodel.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart';
import 'package:kakeibo_smartphone_app/utils/formatter.dart';
import 'package:kakeibo_smartphone_app/utils/app_constants.dart';
import 'package:kakeibo_smartphone_app/models/tag.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _exportCsv(List<Transaction> transactions) async {
    List<List<dynamic>> rows = [];
    rows.add(['日付', 'タイプ', '金額', 'タグ', 'メモ']);

    for (var t in transactions) {
      rows.add([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type == 'income' ? '収入' : '支出',
        t.amount,
        t.tag,
        t.memo ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/kakeibo_data.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: '家計簿データ');
  }

  @override
  Widget build(BuildContext context) {
    final settingsViewModel = Provider.of<SettingsViewModel>(context);
    final transactionViewModel = Provider.of<TransactionViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('月の開始日'),
            subtitle: Text(
                '${settingsViewModel.appSettings?.startDayOfMonth ?? 1}日'),
            onTap: () async {
              final selectedDay = await showDialog<int>(
                context: context,
                builder: (BuildContext context) {
                  return SimpleDialog(
                    title: const Text('月の開始日を選択'),
                    children: List.generate(31, (index) {
                      final day = index + 1;
                      return SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context, day);
                        },
                        child: Text('$day日'),
                      );
                    }),
                  );
                },
              );
              if (selectedDay != null) {
                settingsViewModel.updateStartDayOfMonth(selectedDay);
              }
            },
          ),
          ListTile(
            title: const Text('月間予算'),
            subtitle: Text(
                '${Formatter.formatAmount(settingsViewModel.appSettings?.monthlyBudget ?? 0)}円'),
            onTap: () async {
              final newBudget = await _showBudgetInputDialog(context, settingsViewModel.appSettings?.monthlyBudget ?? 0);
              if (newBudget != null) {
                settingsViewModel.updateMonthlyBudget(newBudget);
              }
            },
          ),
          ListTile(
            title: const Text('タグの編集とデフォルト設定'),
            onTap: () {
              _showTagManagementDialog(context, transactionViewModel, settingsViewModel);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('データのエクスポート'),
            subtitle: const Text('全取引履歴をCSVファイルで出力します'),
            leading: const Icon(Icons.download),
            onTap: () {
              _exportCsv(transactionViewModel.transactions);
            },
          ),
          ListTile(
            title: const Text('全データ削除'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('確認'),
                  content: const Text('すべてのデータを削除してもよろしいですか？この操作は元に戻せません。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('削除'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await settingsViewModel.resetAllData();
                // TransactionViewModelのデータもリロード
                await transactionViewModel.addTransaction(Transaction(amount: 0, type: '', date: DateTime.now(), tag: '')); // ダミーで更新をトリガー
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('すべてのデータが削除されました。')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<int?> _showBudgetInputDialog(BuildContext context, int currentBudget) async {
    final TextEditingController controller = TextEditingController(text: currentBudget.toString());
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('月間予算を設定'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '予算を入力してください (上限: ${Formatter.formatAmount(AppConstants.MAX_AMOUNT)}円)',
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              final int? parsedValue = int.tryParse(value);
              if (parsedValue != null && parsedValue > AppConstants.MAX_AMOUNT) {
                controller.text = AppConstants.MAX_AMOUNT.toString();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('入力上限を超えています。')),
                );
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final int? newBudget = int.tryParse(controller.text);
              if (newBudget != null && newBudget <= AppConstants.MAX_AMOUNT) {
                Navigator.pop(context, newBudget);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('無効な金額です。')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showTagManagementDialog(BuildContext context, TransactionViewModel transactionViewModel, SettingsViewModel settingsViewModel) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ScaffoldMessenger(
          key: GlobalKey<ScaffoldMessengerState>(), // 独立させる
          child: Builder(
            builder: (snackContext) {
              return AlertDialog(
                title: const Text('タグの編集とデフォルト設定'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    body: Consumer<SettingsViewModel>(
                      builder: (consumerContext, settings, child) {
                        return DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: '支出タグ'),
                                  Tab(text: '収入タグ'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildTagListAndDefaultSettings(
                                      snackContext, // 変更！
                                      transactionViewModel,
                                      settings,
                                      'expense',
                                    ),
                                    _buildTagListAndDefaultSettings(
                                      snackContext, // 変更！
                                      transactionViewModel,
                                      settings,
                                      'income',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('閉じる'),
                  ),
                ],
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildTagListAndDefaultSettings(
    BuildContext context,
    TransactionViewModel transactionViewModel,
    SettingsViewModel settingsViewModel,
    String type,
  ) {
    var allTags = transactionViewModel.tags.where((tag) => tag.type == type).toList();
    final defaultTags = type == 'income'
        ? settingsViewModel.appSettings?.defaultIncomeTags
        : settingsViewModel.appSettings?.defaultExpenseTags;

    // 「未設定」タグを一番上に持ってくる
    final unassignedTag = allTags.firstWhere((tag) => tag.name == '未設定', orElse: () => Tag(id: -1, name: '未設定', type: type, isDeletable: false));
    allTags = allTags.where((tag) => tag.name != '未設定').toList();
    allTags.insert(0, unassignedTag);

    return Column(
      children: [
        // 全タグリスト
        Expanded(
          child: Builder(
            builder: (BuildContext innerContext) {
              return ListView(
                shrinkWrap: true,
                children: [
                  ...allTags.map((tag) {
                    final isDefault = defaultTags?.contains(tag.name) ?? false;
                    final isDeletable = tag.isDeletable;

                    Widget tile = ListTile(
                      leading: IconButton(
                        icon: Icon(
                          isDefault ? Icons.favorite : Icons.favorite_border,
                          color: isDefault ? Colors.red : null,
                        ),
                        onPressed: () {
                          List<String> currentDefaults = List.from(defaultTags ?? []);
                          if (isDefault) {
                            currentDefaults.remove(tag.name);
                          } else {
                            if (currentDefaults.length < 3) {
                              currentDefaults.add(tag.name);
                            } else {
                              ScaffoldMessenger.of(innerContext).showSnackBar( // innerContext を使用
                                const SnackBar(content: Text('お気に入りタグは最大3つまでです。')),
                              );
                            }
                          }
                          if (type == 'income') {
                            settingsViewModel.updateDefaultIncomeTags(currentDefaults);
                          } else {
                            settingsViewModel.updateDefaultExpenseTags(currentDefaults);
                          }
                        },
                      ),
                      title: Text(tag.name),
                      trailing: isDeletable ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final newTagName = await _showTagInputDialog(innerContext, tag.name); // innerContext を使用
                          if (newTagName != null && newTagName.isNotEmpty) {
                            transactionViewModel.updateTag(Tag(id: tag.id, name: newTagName, type: tag.type, isDeletable: tag.isDeletable));
                          }
                        },
                      ) : null,
                    );

                    if (isDeletable) {
                      return Dismissible(
                        key: Key(tag.id.toString()), // UniqueKey for Dismissible
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: innerContext, // innerContext を使用
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("確認"),
                                content: Text("'${tag.name}'を削除してもよろしいですか？"),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text("キャンセル"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text("削除"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          transactionViewModel.deleteTag(tag.id!); // タグを削除
                          // デフォルトタグからも削除
                          List<String> currentDefaults = List.from(defaultTags ?? []);
                          if (currentDefaults.contains(tag.name)) {
                            currentDefaults.remove(tag.name);
                            if (type == 'income') {
                              settingsViewModel.updateDefaultIncomeTags(currentDefaults);
                            } else {
                              settingsViewModel.updateDefaultExpenseTags(currentDefaults);
                            }
                          }
                          ScaffoldMessenger.of(innerContext).showSnackBar( // innerContext を使用
                            SnackBar(content: Text('${tag.name}を削除しました')),
                          );
                        },
                        child: tile,
                      );
                    } else {
                      return tile;
                    }
                  }),
                  ListTile(
                    title: const Text('新しいタグを追加'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final newTagName = await _showTagInputDialog(innerContext); // innerContext を使用
                        if (newTagName != null && newTagName.isNotEmpty) {
                          transactionViewModel.addTag(Tag(name: newTagName, type: type));
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<String?> _showTagInputDialog(BuildContext context, [String? initialValue]) {
    final TextEditingController controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialValue == null ? '新しいタグを追加' : 'タグを編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'タグ名を入力'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}