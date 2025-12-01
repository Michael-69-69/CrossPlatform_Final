// screens/student/student_material_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/material.dart' as app;
import '../../providers/material_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/file_download_helper.dart';
import '../../main.dart'; // for localeProvider

class StudentMaterialView extends ConsumerStatefulWidget {
  final app.Material material;

  const StudentMaterialView({super.key, required this.material});

  @override
  ConsumerState<StudentMaterialView> createState() => _StudentMaterialViewState();
}

class _StudentMaterialViewState extends ConsumerState<StudentMaterialView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Record view
      final user = ref.read(authProvider);
      if (user != null) {
        ref.read(materialViewProvider.notifier).recordView(
              materialId: widget.material.id,
              studentId: user.id,
              downloaded: false,
            );
      }
    });
  }

  // Helper method to check if Vietnamese
  bool _isVietnamese() {
    return ref.read(localeProvider).languageCode == 'vi';
  }

  @override
  Widget build(BuildContext context) {
    final isVietnamese = ref.watch(localeProvider).languageCode == 'vi';

    return Scaffold(
      appBar: AppBar(
        title: Text(isVietnamese ? 'Tài liệu' : 'Material'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.material.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            if (widget.material.description != null) ...[
              Text(
                isVietnamese ? 'Mô tả:' : 'Description:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(widget.material.description!),
              const SizedBox(height: 16),
            ],

            const Divider(),

            // Attachments
            Text(
              isVietnamese ? 'Tệp đính kèm:' : 'Attachments:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            if (widget.material.attachments.isEmpty)
              Text(isVietnamese ? 'Không có tệp đính kèm' : 'No attachments')
            else
              ...widget.material.attachments.map((attachment) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      attachment.isLink ? Icons.link : Icons.attach_file,
                      color: Colors.blue,
                    ),
                    title: Text(attachment.fileName),
                    subtitle: attachment.fileSize != null
                        ? Text('${(attachment.fileSize! / 1024).toStringAsFixed(1)} KB')
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadFile(attachment),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(app.MaterialAttachment attachment) async {
    final isVietnamese = _isVietnamese();
    try {
      if (attachment.isLink) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link: ${attachment.fileUrl ?? ""}')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isVietnamese ? 'Đang tải xuống...' : 'Downloading...')),
        );
      }

      String result;

      if (attachment.fileData != null && attachment.fileData!.isNotEmpty) {
        final path = await FileDownloadHelper.downloadFromBase64(
          base64Data: attachment.fileData!,
          fileName: attachment.fileName,
        );
        result = isVietnamese ? 'Đã tải: $path' : 'Downloaded: $path';
      } else if (attachment.fileUrl != null &&
          (attachment.fileUrl!.startsWith('http://') ||
              attachment.fileUrl!.startsWith('https://'))) {
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        result = isVietnamese ? 'Đã tải: $path' : 'Downloaded: $path';
      } else if (attachment.fileUrl != null &&
          (attachment.fileUrl!.startsWith('/') || attachment.fileUrl!.contains('\\'))) {
        final downloaded = await FileDownloadHelper.downloadFromLocalPath(
          localPath: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        result = downloaded != null
            ? (isVietnamese ? 'Đã tải: $downloaded' : 'Downloaded: $downloaded')
            : (isVietnamese ? 'Không thể tải file local trên web' : 'Cannot download local file on web');
      } else {
        throw Exception(isVietnamese ? 'Không có nguồn file hợp lệ' : 'No valid file source available');
      }

      // Track download
      final user = ref.read(authProvider);
      if (user != null) {
        ref.read(materialViewProvider.notifier).trackDownload(
              materialId: widget.material.id,
              studentId: user.id,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isVietnamese ? 'Lỗi' : 'Error'}: $e')),
        );
      }
    }
  }
}