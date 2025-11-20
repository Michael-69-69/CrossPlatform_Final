// screens/student/tabs/student_material_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/material.dart' as app;
import '../../../providers/material_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/file_download_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu'),
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
              const Text(
                'Mô tả:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(widget.material.description!),
              const SizedBox(height: 16),
            ],

            const Divider(),

            // Attachments
            const Text(
              'Tệp đính kèm:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            if (widget.material.attachments.isEmpty)
              const Text('Không có tệp đính kèm')
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
          const SnackBar(content: Text('Đang tải xuống...')),
        );
      }

      String result;

      if (attachment.fileData != null && attachment.fileData!.isNotEmpty) {
        final path = await FileDownloadHelper.downloadFromBase64(
          base64Data: attachment.fileData!,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } else if (attachment.fileUrl != null &&
          (attachment.fileUrl!.startsWith('http://') ||
              attachment.fileUrl!.startsWith('https://'))) {
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } else if (attachment.fileUrl != null &&
          (attachment.fileUrl!.startsWith('/') || attachment.fileUrl!.contains('\\'))) {
        final downloaded = await FileDownloadHelper.downloadFromLocalPath(
          localPath: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        result = downloaded != null ? 'Đã tải: $downloaded' : 'Không thể tải file local trên web';
      } else {
        throw Exception('No valid file source available');
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
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}