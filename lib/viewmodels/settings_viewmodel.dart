import 'package:flutter/material.dart';
import 'package:kakeibo_smartphone_app/models/app_settings.dart';
import 'package:kakeibo_smartphone_app/services/database_helper.dart';

class SettingsViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  AppSettings? _appSettings;

  AppSettings? get appSettings => _appSettings;

  SettingsViewModel() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _appSettings = await _dbHelper.getAppSettings();
    if (_appSettings == null) {
      // 初期設定が存在しない場合、デフォルト値で作成（DBには保存しない）
      _appSettings = AppSettings(startDayOfMonth: 1, monthlyBudget: 0, defaultIncomeTags: ['給料'], defaultExpenseTags: ['食費', '交通費', '娯楽費']);
      // updateメソッドが初回保存をハンドルする
      await _dbHelper.updateAppSettings(_appSettings!);
    }
    notifyListeners();
  }

  Future<void> updateStartDayOfMonth(int day) async {
    if (_appSettings != null) {
      _appSettings = AppSettings(
        id: _appSettings!.id,
        startDayOfMonth: day,
        monthlyBudget: _appSettings!.monthlyBudget,
        defaultIncomeTags: _appSettings!.defaultIncomeTags,
        defaultExpenseTags: _appSettings!.defaultExpenseTags,
      );
      await _dbHelper.updateAppSettings(_appSettings!);
      notifyListeners();
    }
  }

  Future<void> updateMonthlyBudget(int budget) async {
    if (_appSettings != null) {
      _appSettings = AppSettings(
        id: _appSettings!.id,
        startDayOfMonth: _appSettings!.startDayOfMonth,
        monthlyBudget: budget,
        defaultIncomeTags: _appSettings!.defaultIncomeTags,
        defaultExpenseTags: _appSettings!.defaultExpenseTags,
      );
      await _dbHelper.updateAppSettings(_appSettings!);
      notifyListeners();
    }
  }

  Future<void> updateDefaultIncomeTags(List<String> tags) async {
    if (_appSettings != null) {
      _appSettings = AppSettings(
        id: _appSettings!.id,
        startDayOfMonth: _appSettings!.startDayOfMonth,
        monthlyBudget: _appSettings!.monthlyBudget,
        defaultIncomeTags: tags,
        defaultExpenseTags: _appSettings!.defaultExpenseTags,
      );
      await _dbHelper.updateAppSettings(_appSettings!);
      notifyListeners();
    }
  }

  Future<void> updateDefaultExpenseTags(List<String> tags) async {
    if (_appSettings != null) {
      _appSettings = AppSettings(
        id: _appSettings!.id,
        startDayOfMonth: _appSettings!.startDayOfMonth,
        monthlyBudget: _appSettings!.monthlyBudget,
        defaultIncomeTags: _appSettings!.defaultIncomeTags,
        defaultExpenseTags: tags,
      );
      await _dbHelper.updateAppSettings(_appSettings!);
      notifyListeners();
    }
  }

  Future<void> resetAllData() async {
    await _dbHelper.deleteAllData();
    await _loadSettings(); // 設定もリロード
    // 必要であれば、TransactionViewModelのデータもリロードする
    // Provider.of<TransactionViewModel>(context, listen: false)._loadTransactions();
    notifyListeners();
  }
}
