// models/csv_preview_item.dart
class CsvPreviewItem {
  final int rowIndex;
  final String code;
  final String fullName;
  final String email;
  final String status; // 'new', 'exists', 'invalid', 'duplicate'
  final String? errorMessage;
  final bool selected; // For selective import

  CsvPreviewItem({
    required this.rowIndex,
    required this.code,
    required this.fullName,
    required this.email,
    required this.status,
    this.errorMessage,
    this.selected = true,
  });

  CsvPreviewItem copyWith({
    int? rowIndex,
    String? code,
    String? fullName,
    String? email,
    String? status,
    String? errorMessage,
    bool? selected,
  }) {
    return CsvPreviewItem(
      rowIndex: rowIndex ?? this.rowIndex,
      code: code ?? this.code,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      selected: selected ?? this.selected,
    );
  }
}


