class Transaction {
  final int? id;
  final DateTime date;
  final double amount;
  final String type; // 'income' or 'expense'
  final String tag;
  final String? memo;

  Transaction({
    this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.tag,
    this.memo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'type': type,
      'tag': tag,
      'memo': memo,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'],
      type: map['type'],
      tag: map['tag'],
      memo: map['memo'],
    );
  }

  @override
  String toString() {
    return 'Transaction(id: \$id, date: \$date, amount: \$amount, type: \$type, tag: \$tag, memo: \$memo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Transaction &&
        other.id == id &&
        other.date == date &&
        other.amount == amount &&
        other.type == type &&
        other.tag == tag &&
        other.memo == memo;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        date.hashCode ^
        amount.hashCode ^
        type.hashCode ^
        tag.hashCode ^
        memo.hashCode;
  }
}
