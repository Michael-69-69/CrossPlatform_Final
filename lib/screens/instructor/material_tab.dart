// screens/instructor/material_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/material.dart' as app;
import '../../models/user.dart';
import '../../providers/material_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/file_upload_helper.dart';   // ✅ NEW
import '../../utils/file_download_helper.dart'; // ✅ UPDATED

class MaterialTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  final List<AppUser> students;

  const MaterialTab({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.students,
  });

  @override
  ConsumerState<MaterialTab> createState() => _MaterialTabState();
}

class _MaterialTabState extends ConsumerState<MaterialTab> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(materialProvider.notifier).loadMaterials(courseId: widget.courseId);
      ref.read(materialViewProvider.notifier).loadViews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final materials = ref.watch(materialProvider)
        .where((m) => m.courseId == widget.courseId)
        .toList();

    final filteredMaterials = materials.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Create Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm tài liệu'),
            onPressed: () => _showCreateMaterialDialog(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tài liệu...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        const SizedBox(height: 8),
        // Material List
        Expanded(
          child: filteredMaterials.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Không tìm thấy tài liệu nào'
                        : 'Chưa có tài liệu nào',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMaterials.length,
                  itemBuilder: (context, index) {
                    final material = filteredMaterials[index];
                    return _MaterialCard(
                      material: material,
                      students: widget.students,
                      onTap: () => _showMaterialDetail(context, material),
                      onDelete: () => _deleteMaterial(material.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateMaterialDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final attachments = <app.MaterialAttachment>[];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm tài liệu'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text('Tệp đính kèm / Liên kết:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Chọn tệp'),
                          onPressed: () async {
                            try {
                              // ✅ NEW: Use file upload helper to encode files
                              final encodedFiles = await FileUploadHelper.pickAndEncodeMultipleFiles();
                              
                              if (encodedFiles.isNotEmpty) {
                                setDialogState(() {
                                  for (final fileData in encodedFiles) {
                                    attachments.add(app.MaterialAttachment(
                                      fileName: fileData['fileName'],
                                      fileData: fileData['fileData'],  // ✅ Store Base64
                                      fileSize: fileData['fileSize'],
                                      mimeType: fileData['mimeType'],
                                      isLink: false,
                                    ));
                                  }
                                });
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi tải file: $e')),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.link),
                          label: const Text('Thêm link'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (linkCtx) => AlertDialog(
                                title: const Text('Thêm liên kết'),
                                content: TextField(
                                  controller: linkCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'URL',
                                    hintText: 'https://example.com',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(linkCtx),
                                    child: const Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (linkCtrl.text.trim().isNotEmpty) {
                                        setDialogState(() {
                                          attachments.add(app.MaterialAttachment(
                                            fileName: Uri.parse(linkCtrl.text.trim()).pathSegments.lastOrNull ?? 'Link',
                                            fileUrl: linkCtrl.text.trim(),
                                            isLink: true,
                                          ));
                                          linkCtrl.clear();
                                        });
                                        Navigator.pop(linkCtx);
                                      }
                                    },
                                    child: const Text('Thêm'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...attachments.map((attachment) {
                      return ListTile(
                        leading: Icon(attachment.isLink ? Icons.link : Icons.attachment),
                        title: Text(attachment.fileName),
                        subtitle: attachment.fileSize != null
                            ? Text('${(attachment.fileSize! / 1024).toStringAsFixed(1)} KB')
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              attachments.remove(attachment);
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ref.read(materialProvider.notifier).createMaterial(
                        courseId: widget.courseId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        attachments: attachments,
                      );
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã thêm tài liệu')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialDetail(BuildContext context, app.Material material) {
    final views = ref.read(materialViewProvider)
        .where((v) => v.materialId == material.id)
        .toList();
    final viewedStudentIds = views.map((v) => v.studentId).toSet();
    final notViewed = widget.students.where((s) => !viewedStudentIds.contains(s.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MaterialDetailSheet(
        material: material,
        materialId: material.id, // ✅ Pass materialId
        students: widget.students,
        views: views,
        notViewed: notViewed,
        onDownload: (attachment) => _downloadFile(context, material.id, attachment),
      ),
    );
  }

  // ✅ UPDATED: Handle Base64, URL, and local paths
  Future<void> _downloadFile(BuildContext context, String materialId, app.MaterialAttachment attachment) async {
    try {
      // Record the download in database
      final user = ref.read(authProvider);
      if (user != null) {
        ref.read(materialViewProvider.notifier).trackDownload(
          materialId: materialId,
          studentId: user.id,
        );
      }

      if (attachment.isLink) {
        // For links, show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link: ${attachment.fileUrl ?? ""}')),
          );
        }
        return;
      }

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải xuống...')),
        );
      }

      String result;

      // Check if it's Base64 data, URL, or local path
      if (attachment.fileData != null && attachment.fileData!.isNotEmpty) {
        // ✅ Base64 data - download from encoded data
        final path = await FileDownloadHelper.downloadFromBase64(
          base64Data: attachment.fileData!,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } else if (attachment.fileUrl != null && 
                 (attachment.fileUrl!.startsWith('http://') || 
                  attachment.fileUrl!.startsWith('https://'))) {
        // URL - download from internet
        final path = await FileDownloadHelper.downloadFile(
          url: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        result = 'Đã tải: $path';
      } else if (attachment.fileUrl != null &&
                 (attachment.fileUrl!.startsWith('/') || 
                  attachment.fileUrl!.contains('\\'))) {
        // Local file path (mobile only)
        final downloaded = await FileDownloadHelper.downloadFromLocalPath(
          localPath: attachment.fileUrl!,
          fileName: attachment.fileName,
        );
        
        if (downloaded != null) {
          result = 'Đã tải: $downloaded';
        } else {
          result = 'Không thể tải file local trên web';
        }
      } else {
        throw Exception('No valid file source available');
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

  Future<void> _deleteMaterial(String materialId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài liệu?'),
        content: const Text('Bạn có chắc muốn xóa tài liệu này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(materialProvider.notifier).deleteMaterial(materialId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa tài liệu')),
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
}

class _MaterialCard extends StatelessWidget {
  final app.Material material;
  final List<AppUser> students;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MaterialCard({
    required this.material,
    required this.students,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.blue),
        title: Text(material.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (material.description != null) Text(material.description!),
            Text('${material.attachments.length} tệp đính kèm'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'detail',
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text('Chi tiết'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Xóa', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'detail') onTap();
            if (value == 'delete') onDelete();
          },
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MaterialDetailSheet extends ConsumerWidget {
  final app.Material material;
  final String materialId; // ✅ NEW
  final List<AppUser> students;
  final List<app.MaterialView> views;
  final List<AppUser> notViewed;
  final Function(app.MaterialAttachment) onDownload;

  const _MaterialDetailSheet({
    required this.material,
    required this.materialId, // ✅ NEW
    required this.students,
    required this.views,
    required this.notViewed,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (material.description != null)
                          Text(material.description!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Đã xem: ${views.length}/${students.length}'),
            ),
            if (material.attachments.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tệp đính kèm:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: material.attachments.length,
                  itemBuilder: (context, index) {
                    final attachment = material.attachments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(attachment.isLink ? Icons.link : Icons.attachment),
                        title: Text(attachment.fileName),
                        subtitle: attachment.fileSize != null
                            ? Text('${(attachment.fileSize! / 1024).toStringAsFixed(1)} KB')
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => onDownload(attachment),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Đã xem'),
                        Tab(text: 'Chưa xem'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildViewedList(views, students),
                          _buildNotViewedList(notViewed),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewedList(List<app.MaterialView> views, List<AppUser> students) {
    return ListView.builder(
      itemCount: views.length,
      itemBuilder: (context, index) {
        final view = views[index];
        final student = students.firstWhere(
          (s) => s.id == view.studentId,
          orElse: () => AppUser(
            id: view.studentId,
            fullName: 'Unknown',
            email: '',
            role: UserRole.student,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        return ListTile(
          leading: CircleAvatar(child: Text(student.fullName[0])),
          title: Text(student.fullName),
          subtitle: Text('${student.code} • ${view.downloaded ? "Đã tải" : "Đã xem"}'),
          trailing: Text(
            '${view.viewedAt.day}/${view.viewedAt.month} ${view.viewedAt.hour}:${view.viewedAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildNotViewedList(List<AppUser> students) {
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          leading: CircleAvatar(child: Text(student.fullName[0])),
          title: Text(student.fullName),
          subtitle: Text('${student.code} • ${student.email}'),
          trailing: const Icon(Icons.close, color: Colors.red),
        );
      },
    );
  }
}