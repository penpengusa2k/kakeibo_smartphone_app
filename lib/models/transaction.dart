class Transaction {
  final int? id;
  final int amount;
  final String type; // 'income' or 'expense'
  final DateTime date;
  final String tag;
  final String? memo;

  Transaction({
    this.id,
    required this.amount,
    required this.type,
    required this.date,
    required this.tag,
    this.memo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'tag': tag,
      'memo': memo,
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      amount: map['amount'],
      type: map['type'],
      date: DateTime.parse(map['date']),
      tag: map['tag'],
      memo: map['memo'],
    );
  }
}
