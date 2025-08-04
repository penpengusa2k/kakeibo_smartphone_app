class Tag {
  final int? id;
  final String name;
  final String type; // 'income' or 'expense'
  final bool isDeletable;

  Tag({
    this.id,
    required this.name,
    required this.type,
    this.isDeletable = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isDeletable': isDeletable ? 1 : 0,
    };
  }

  static Tag fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      isDeletable: map['isDeletable'] == 1,
    );
  }
}
