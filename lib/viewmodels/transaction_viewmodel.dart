import 'package:flutter/material.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/models/tag.dart';
import 'package:kakeibo_smartphone_app/services/database_helper.dart';

class TransactionViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Transaction> _transactions = [];
  List<Tag> _tags = [];

  List<Transaction> get transactions => _transactions;
  List<Tag> get tags => _tags;

  TransactionViewModel() {
    _loadTransactions();
    _loadTags();
  }

  Future<void> _loadTransactions() async {
    _transactions = await _dbHelper.getTransactions();
    notifyListeners();
  }

  Future<void> _loadTags() async {
    _tags = await _dbHelper.getTags();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _dbHelper.insertTransaction(transaction);
    await _loadTransactions();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _dbHelper.updateTransaction(transaction);
    await _loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _dbHelper.deleteTransaction(id);
    await _loadTransactions();
  }

  Future<List<Transaction>> getTransactionsForMonth(int year, int month) async {
    return await _dbHelper.getTransactionsByMonth(year, month);
  }

  Future<void> addTag(Tag tag) async {
    await _dbHelper.insertTag(tag);
    await _loadTags();
  }

  Future<void> updateTag(Tag tag) async {
    await _dbHelper.updateTag(tag);
    await _loadTags();
  }

  Future<void> deleteTag(int id) async {
    await _dbHelper.deleteTag(id);
    await _loadTags();
  }

  // 特定のタイプ（収入/支出）のタグを取得
  List<Tag> getTagsByType(String type) {
    return _tags.where((tag) => tag.type == type).toList();
  }

  // 月ごとの合計金額を取得
  Future<int> getMonthlyTotalAmount(int year, int month, String type) async {
    return await _dbHelper.getMonthlyTotalAmount(year, month, type);
  }
}
