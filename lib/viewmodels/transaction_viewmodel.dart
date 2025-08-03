import 'package:flutter/material.dart';
import 'package:kakeibo_smartphone_app/database/database_helper.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';

class TransactionViewModel extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Transaction> _transactions = [];

  List<Transaction> get transactions => _transactions;

  TransactionViewModel() {
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    _transactions = await _dbHelper.getTransactions();
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

  Future<List<Transaction>> getTransactions() async {
    return await _dbHelper.getTransactions();
  }

  Future<List<Transaction>> getTransactionsByDate(DateTime date) async {
    return await _dbHelper.getTransactionsByDate(date);
  }

  Future<List<Transaction>> getTransactionsByMonth(DateTime month) async {
    return await _dbHelper.getTransactionsByMonth(month);
  }
}
