class ScanRecord {
  final String id;
  final String value;
  final String format;
  final String source; // 'scan' | 'gallery' | 'generated'
  final DateTime scannedAt;
  final bool isFavourite;

  ScanRecord({
    required this.id,
    required this.value,
    required this.format,
    required this.source,
    required this.scannedAt,
    this.isFavourite = false,
  });

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      id: json['id'] as String,
      value: json['value'] as String,
      format: json['format'] as String,
      source: json['source'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      isFavourite: json['isFavourite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'format': format,
      'source': source,
      'scannedAt': scannedAt.toIso8601String(),
      'isFavourite': isFavourite,
    };
  }

  ScanRecord copyWith({bool? isFavourite}) {
    return ScanRecord(
      id: id,
      value: value,
      format: format,
      source: source,
      scannedAt: scannedAt,
      isFavourite: isFavourite ?? this.isFavourite,
    );
  }
}
