class AppSettings {
  final int? id;
  final int startDayOfMonth;
  final int monthlyBudget;
  final List<String> defaultIncomeTags; // 収入用デフォルトタグ
  final List<String> defaultExpenseTags; // 支出用デフォルトタグ

  AppSettings({
    this.id,
    required this.startDayOfMonth,
    required this.monthlyBudget,
    this.defaultIncomeTags = const [],
    this.defaultExpenseTags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startDayOfMonth': startDayOfMonth,
      'monthlyBudget': monthlyBudget,
      'defaultIncomeTags': defaultIncomeTags.join(','),
      'defaultExpenseTags': defaultExpenseTags.join(','),
    };
  }

  static AppSettings fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'],
      startDayOfMonth: map['startDayOfMonth'],
      monthlyBudget: map['monthlyBudget'],
      defaultIncomeTags: (map['defaultIncomeTags'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList(),
      defaultExpenseTags: (map['defaultExpenseTags'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList(),
    );
  }
}
