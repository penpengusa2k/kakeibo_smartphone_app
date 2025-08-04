import 'package:sqflite/sqflite.dart' as sqf;
import 'package:path/path.dart';
import 'package:kakeibo_smartphone_app/models/transaction.dart';
import 'package:kakeibo_smartphone_app/models/tag.dart';
import 'package:kakeibo_smartphone_app/models/app_settings.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static sqf.Database? _database;

  DatabaseHelper._privateConstructor();

  Future<sqf.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sqf.Database> _initDatabase() async {
    String path = join(await sqf.getDatabasesPath(), 'kakeibo_app.db');
    return await sqf.openDatabase(
      path,
      version: 2, // DBバージョンを2に更新
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // スキーマ移行のためのロジック
    );
  }

  // 新規インストール時のテーブル作成
  Future _onCreate(sqf.Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        tag TEXT NOT NULL,
        memo TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isDeletable INTEGER NOT NULL DEFAULT 1,
        UNIQUE(name, type) -- nameとtypeの組み合わせでユニーク
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startDayOfMonth INTEGER NOT NULL,
        monthlyBudget INTEGER NOT NULL,
        defaultIncomeTags TEXT,
        defaultExpenseTags TEXT
      )
    ''');

    await _insertInitialData(db);
  }

  // DBのバージョンアップ時の処理
  Future _onUpgrade(sqf.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2: tagsテーブルの再構築 (isDeletableカラムの追加とUNIQUE制約の変更)
      await db.execute('''
        CREATE TABLE tags_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          isDeletable INTEGER NOT NULL DEFAULT 1,
          UNIQUE(name, type)
        )
      ''');
      // 既存データを新しいテーブルにコピー (既存タグは全て削除可能とする)
      await db.execute('INSERT INTO tags_new (id, name, type, isDeletable) SELECT id, name, type, 1 FROM tags');
      await db.execute('DROP TABLE tags');
      await db.execute('ALTER TABLE tags_new RENAME TO tags');

      // 削除不可の「未設定」タグを追加 (既に存在する場合は無視)
      await db.insert('tags', Tag(name: '未設定', type: 'expense', isDeletable: false).toMap(), conflictAlgorithm: sqf.ConflictAlgorithm.ignore);
      await db.insert('tags', Tag(name: '未設定', type: 'income', isDeletable: false).toMap(), conflictAlgorithm: sqf.ConflictAlgorithm.ignore);
    }
  }

  // 初期データの投入
  Future<void> _insertInitialData(sqf.Database db) async {
    // 初期タグ
    final initialTags = [
      Tag(name: '未設定', type: 'expense', isDeletable: false),
      Tag(name: '食費', type: 'expense'),
      Tag(name: '交通費', type: 'expense'),
      Tag(name: '日用品', type: 'expense'),
      Tag(name: '住居費', type: 'expense'),
      Tag(name: '水道光熱費', type: 'expense'),
      Tag(name: '通信費', type: 'expense'),
      Tag(name: '医療費', type: 'expense'),
      Tag(name: '教育費', type: 'expense'),
      Tag(name: '娯楽費', type: 'expense'),
      Tag(name: '交際費', type: 'expense'),
      Tag(name: '被服費', type: 'expense'),
      Tag(name: '美容費', type: 'expense'),
      Tag(name: '保険', type: 'expense'),
      Tag(name: '税金', type: 'expense'),
      Tag(name: 'その他支出', type: 'expense'),
      Tag(name: '未設定', type: 'income', isDeletable: false),
      Tag(name: '給料', type: 'income'),
    ];

    for (var tag in initialTags) {
      await db.insert('tags', tag.toMap(), conflictAlgorithm: sqf.ConflictAlgorithm.ignore);
    }

    // 初期設定
    await db.insert('app_settings', AppSettings(startDayOfMonth: 1, monthlyBudget: 0, defaultIncomeTags: ['給料'], defaultExpenseTags: ['食費', '交通費', '娯楽費']).toMap());
  }

  // --- Transaction Operations ---
  Future<int> insertTransaction(Transaction transaction) async {
    sqf.Database db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getTransactions() async {
    sqf.Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('transactions');
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<List<Transaction>> getTransactionsByMonth(int year, int month) async {
    sqf.Database db = await instance.database;
    DateTime startDate = DateTime(year, month, 1);
    DateTime endDate = DateTime(year, month + 1, 0);
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date ASC',
    );
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<int> updateTransaction(Transaction transaction) async {
    sqf.Database db = await instance.database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    sqf.Database db = await instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Tag Operations ---
  Future<int> insertTag(Tag tag) async {
    sqf.Database db = await instance.database;
    return await db.insert('tags', tag.toMap(), conflictAlgorithm: sqf.ConflictAlgorithm.replace);
  }

  Future<List<Tag>> getTags() async {
    sqf.Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('tags');
    return List.generate(maps.length, (i) {
      return Tag.fromMap(maps[i]);
    });
  }

  Future<int> updateTag(Tag tag) async {
    sqf.Database db = await instance.database;
    return await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  Future<int> deleteTag(int id) async {
    sqf.Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final tag = Tag.fromMap(maps.first);
      if (!tag.isDeletable) {
        return 0; // 削除不可のタグは削除しない
      }
    }
    return await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 月ごとの合計金額を取得
  Future<int> getMonthlyTotalAmount(int year, int month, String type) async {
    sqf.Database db = await instance.database;
    DateTime startDate = DateTime(year, month, 1);
    DateTime endDate = DateTime(year, month + 1, 0); // その月の最終日

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND date BETWEEN ? AND ?',
      [type, startDate.toIso8601String(), endDate.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    } else {
      return 0;
    }
  }

  // --- AppSettings Operations ---
  Future<AppSettings?> getAppSettings() async {
    sqf.Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('app_settings');
    if (maps.isNotEmpty) {
      return AppSettings.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateAppSettings(AppSettings settings) async {
    sqf.Database db = await instance.database;
    // AppSettingsは通常1つしかないので、IDを指定せずに更新（または挿入）
    final count = await db.update('app_settings', settings.toMap());
    if (count == 0) {
      return await db.insert('app_settings', settings.toMap());
    }
    return count;
  }

  // 全データ削除
  Future<void> deleteAllData() async {
    sqf.Database db = await instance.database;
    await db.delete('transactions');
    await db.delete('tags');
    await db.delete('app_settings');
    await _insertInitialData(db);
  }
}
