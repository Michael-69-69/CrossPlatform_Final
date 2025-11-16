// screens/instructor/csv_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'dart:convert';
import '../../models/csv_preview_item.dart';
import '../../models/user.dart';
import '../../providers/student_provider.dart';

class CsvPreviewScreen extends ConsumerStatefulWidget {
  const CsvPreviewScreen({super.key});

  @override
  ConsumerState<CsvPreviewScreen> createState() => _CsvPreviewScreenState();
}

class _CsvPreviewScreenState extends ConsumerState<CsvPreviewScreen> {
  String? _csvContent;
  String? _fileName;
  List<CsvPreviewItem> _previewItems = [];
  bool _isLoading = false;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _pickCsvFile();
  }

  Future<void> _pickCsvFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null) {
        _fileName = result.files.single.name;
        final filePath = result.files.single.path;
        
        // Read file content
        if (kIsWeb) {
          // Web: use bytes directly
          final bytes = result.files.single.bytes;
          if (bytes != null) {
            _csvContent = utf8.decode(bytes);
          }
        } else {
          // Mobile/Desktop: read from file path or bytes
          if (filePath != null && filePath.isNotEmpty) {
            final file = io.File(filePath);
            _csvContent = await file.readAsString();
          } else {
            final bytes = result.files.single.bytes;
            if (bytes != null) {
              _csvContent = utf8.decode(bytes);
            }
          }
        }

        if (_csvContent != null) {
          await _previewCsv();
        }
      } else {
        // User cancelled, go back
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đọc file: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _previewCsv() async {
    if (_csvContent == null || _csvContent!.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (_csvContent == null) return;
      final existingStudents = ref.read(studentProvider);
      final previewItems = await ref.read(studentProvider.notifier).previewCsvData(
        _csvContent!,
        existingStudents,
      );

      setState(() {
        _previewItems = previewItems;
        _selectAll = previewItems.where((item) => item.status == 'new').isNotEmpty;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý CSV: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      _previewItems = _previewItems.map((item) {
        if (item.status == 'new') {
          return item.copyWith(selected: _selectAll);
        }
        return item;
      }).toList();
    });
  }

  void _toggleItem(int index) {
    setState(() {
      final item = _previewItems[index];
      if (item.status == 'new') {
        _previewItems[index] = item.copyWith(selected: !item.selected);
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.green;
      case 'exists':
        return Colors.orange;
      case 'duplicate':
        return Colors.red;
      case 'invalid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'new':
        return 'Sẽ thêm';
      case 'exists':
        return 'Đã tồn tại';
      case 'duplicate':
        return 'Trùng lặp';
      case 'invalid':
        return 'Lỗi';
      default:
        return status;
    }
  }

  Future<void> _downloadCsv() async {
    if (_csvContent == null) return;

    try {
      await Clipboard.setData(ClipboardData(text: _csvContent!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép CSV vào clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _viewCsv() async {
    if (_csvContent == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nội dung CSV: $_fileName'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _csvContent!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () {
              _downloadCsv();
              Navigator.pop(ctx);
            },
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSelected() async {
    final selectedCount = _previewItems.where((item) => item.selected && item.status == 'new').length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có mục nào được chọn để nhập')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nhập'),
        content: Text('Bạn có chắc muốn nhập $selectedCount sinh viên?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nhập'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(studentProvider.notifier).importStudentsFromCsvPreview(_previewItems);
      
      if (mounted) {
        Navigator.pop(context); // Close preview screen
        _showImportResults(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi nhập: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImportResults(Map<String, dynamic> result) {
    final created = result['created'] as List<AppUser>;
    final errors = result['errors'] as List<String>;
    final skipped = result['skipped'] as List<String>;
    final total = result['total'] as int;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết quả nhập'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng số: $total', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('✅ Đã thêm: ${created.length}', style: const TextStyle(color: Colors.green)),
              if (skipped.isNotEmpty)
                Text('⏭️ Đã bỏ qua: ${skipped.length}', style: const TextStyle(color: Colors.orange)),
              if (errors.isNotEmpty)
                Text('❌ Lỗi: ${errors.length}', style: const TextStyle(color: Colors.red)),
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Chi tiết lỗi:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...errors.take(5).map((e) => Text('• $e', style: const TextStyle(fontSize: 12))),
                if (errors.length > 5)
                  Text('... và ${errors.length - 5} lỗi khác', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem trước CSV'),
        actions: [
          if (_csvContent != null) ...[
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Xem CSV',
              onPressed: _viewCsv,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Sao chép CSV',
              onPressed: _downloadCsv,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _previewItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Chưa có dữ liệu CSV'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Chọn file CSV'),
                        onPressed: _pickCsvFile,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary and controls
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'File: $_fileName',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Chọn file khác'),
                                onPressed: _pickCsvFile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tổng: ${_previewItems.length} | '
                                  'Sẽ thêm: ${_previewItems.where((i) => i.status == 'new' && i.selected).length} | '
                                  'Đã tồn tại: ${_previewItems.where((i) => i.status == 'exists').length} | '
                                  'Lỗi: ${_previewItems.where((i) => i.status == 'invalid' || i.status == 'duplicate').length}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Checkbox(
                                value: _selectAll,
                                onChanged: (v) => _toggleSelectAll(),
                              ),
                              const Text('Chọn tất cả'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Preview list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _previewItems.length,
                        itemBuilder: (context, index) {
                          final item = _previewItems[index];
                          final statusColor = _getStatusColor(item.status);
                          final canSelect = item.status == 'new';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: item.status == 'exists' || item.status == 'invalid' || item.status == 'duplicate'
                                ? Colors.grey.shade100
                                : null,
                            child: ListTile(
                              leading: canSelect
                                  ? Checkbox(
                                      value: item.selected,
                                      onChanged: (v) => _toggleItem(index),
                                    )
                                  : Icon(
                                      item.status == 'exists'
                                          ? Icons.check_circle
                                          : Icons.error,
                                      color: statusColor,
                                    ),
                              title: Text(item.fullName.isNotEmpty ? item.fullName : '(Trống)'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Mã SV: ${item.code}'),
                                  if (item.email.isNotEmpty) Text('Email: ${item.email}'),
                                  if (item.errorMessage != null)
                                    Text(
                                      item.errorMessage!,
                                      style: TextStyle(color: statusColor, fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(
                                  _getStatusText(item.status),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                                backgroundColor: statusColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Import button
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload),
                        label: Text(
                          'Nhập ${_previewItems.where((i) => i.selected && i.status == 'new').length} sinh viên',
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _previewItems.where((i) => i.selected && i.status == 'new').isEmpty
                            ? null
                            : _importSelected,
                      ),
                    ),
                  ],
                ),
    );
  }
}

