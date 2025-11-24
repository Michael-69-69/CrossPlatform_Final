// screens/instructor/cache_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/cache_service.dart';
import '../../services/network_service.dart';

class CacheManagementScreen extends ConsumerStatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  ConsumerState<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends ConsumerState<CacheManagementScreen> {
  Map<String, dynamic>? _cacheStats;
  List<Map<String, dynamic>> _cacheItems = [];
  bool _isLoading = false;
  String _filterKey = '';

  @override
  void initState() {
    super.initState();
    _loadCacheData();
  }

  Future<void> _loadCacheData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await CacheService.getCacheStats();
      final items = await CacheService.getAllCacheItems();
      setState(() {
        _cacheStats = stats;
        _cacheItems = items;
      });
    } catch (e) {
      print('Error loading cache data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache(String? key) async {
    setState(() => _isLoading = true);
    try {
      if (key == null) {
        await CacheService.clearAllCache();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã xóa toàn bộ cache'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await CacheService.clearCache(key);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã xóa cache: $key'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadCacheData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  String _formatDuration(String? expiresAt) {
    if (expiresAt == null) return 'N/A';
    try {
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();
      if (now.isAfter(expiry)) {
        return '❌ Đã hết hạn';
      }
      final diff = expiry.difference(now);
      if (diff.inDays > 0) {
        return '⏰ ${diff.inDays}d ${diff.inHours % 24}h còn';
      } else if (diff.inHours > 0) {
        return '⏰ ${diff.inHours}h ${diff.inMinutes % 60}m còn';
      } else {
        return '⏰ ${diff.inMinutes}m còn';
      }
    } catch (e) {
      return expiresAt;
    }
  }

  Color _getCacheTypeColor(String key) {
    if (key.startsWith('auth_')) return Colors.purple;
    if (key.startsWith('assignments_')) return Colors.orange;
    if (key.startsWith('semester')) return Colors.blue;
    if (key.startsWith('query_')) return Colors.teal;
    if (key == 'semesters') return Colors.indigo;
    if (key == 'courses') return Colors.green;
    if (key == 'groups') return Colors.amber;
    if (key == 'students') return Colors.pink;
    return Colors.grey;
  }

  IconData _getCacheTypeIcon(String key) {
    if (key.startsWith('auth_')) return Icons.person;
    if (key.startsWith('assignments_')) return Icons.assignment;
    if (key.startsWith('semester')) return Icons.calendar_month;
    if (key.startsWith('query_')) return Icons.search;
    if (key == 'semesters') return Icons.calendar_today;
    if (key == 'courses') return Icons.school;
    if (key == 'groups') return Icons.group;
    if (key == 'students') return Icons.people;
    return Icons.storage;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filterKey.isEmpty
        ? _cacheItems
        : _cacheItems.where((item) => 
            item['key'].toString().toLowerCase().contains(_filterKey.toLowerCase())
          ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗄️ Cache Management'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadCacheData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Xóa tất cả',
            onPressed: () => _showClearAllDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Network Status Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: NetworkService().isOnline 
                      ? Colors.green.shade100 
                      : Colors.orange.shade100,
                  child: Row(
                    children: [
                      Icon(
                        NetworkService().isOnline ? Icons.wifi : Icons.wifi_off,
                        color: NetworkService().isOnline ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NetworkService().isOnline 
                            ? '🟢 Online - Dữ liệu sẽ được đồng bộ' 
                            : '🟠 Offline - Sử dụng cache',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: NetworkService().isOnline 
                              ? Colors.green.shade800 
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Statistics Cards
                if (_cacheStats != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildStatCard('Tổng', _cacheStats!['total'], Colors.deepPurple),
                        const SizedBox(width: 8),
                        _buildStatCard('Danh mục', _cacheStats!['category'], Colors.blue),
                        const SizedBox(width: 8),
                        _buildStatCard('Truy vấn', _cacheStats!['query'], Colors.teal),
                        const SizedBox(width: 8),
                        _buildStatCard('Học kỳ', _cacheStats!['semester'], Colors.orange),
                      ],
                    ),
                  ),

                // Quick Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickActionChip('Auth Session', 'auth_session', Colors.purple),
                      _buildQuickActionChip('Semesters', 'semesters', Colors.indigo),
                      _buildQuickActionChip('Courses', 'courses', Colors.green),
                      _buildQuickActionChip('Groups', 'groups', Colors.amber),
                      _buildQuickActionChip('Students', 'students', Colors.pink),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm cache key...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      suffixIcon: _filterKey.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _filterKey = ''),
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _filterKey = value),
                  ),
                ),

                // Cache Items List
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _filterKey.isEmpty 
                                    ? 'Chưa có cache nào' 
                                    : 'Không tìm thấy cache',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildCacheItemCard(item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label, String key, Color color) {
    final hasCache = _cacheItems.any((item) => item['key'] == key);
    
    return ActionChip(
      avatar: Icon(
        hasCache ? Icons.check_circle : Icons.circle_outlined,
        color: hasCache ? color : Colors.grey,
        size: 18,
      ),
      label: Text(label),
      backgroundColor: hasCache ? color.withOpacity(0.1) : Colors.grey.shade200,
      onPressed: hasCache
          ? () => _showCacheDetailDialog(
                _cacheItems.firstWhere((item) => item['key'] == key),
              )
          : null,
    );
  }

  Widget _buildCacheItemCard(Map<String, dynamic> item) {
    final key = item['key'] as String;
    final timestamp = item['timestamp'] as String?;
    final expiresAt = item['expiresAt'] as String?;
    final dataCount = item['dataCount'] as int? ?? 0;
    final color = _getCacheTypeColor(key);
    final icon = _getCacheTypeIcon(key);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          key,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📦 $dataCount mục • ${_formatTimestamp(timestamp)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              _formatDuration(expiresAt),
              style: TextStyle(
                fontSize: 11,
                color: expiresAt != null && DateTime.now().isAfter(DateTime.parse(expiresAt))
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'Xem chi tiết',
              onPressed: () => _showCacheDetailDialog(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              tooltip: 'Xóa',
              onPressed: () => _clearCache(key),
            ),
          ],
        ),
        onTap: () => _showCacheDetailDialog(item),
      ),
    );
  }

  void _showCacheDetailDialog(Map<String, dynamic> item) {
    final key = item['key'] as String;
    final data = item['data'];
    final timestamp = item['timestamp'] as String?;
    final expiresAt = item['expiresAt'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_getCacheTypeIcon(key), color: _getCacheTypeColor(key)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                key,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metadata
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📅 Lưu lúc: ${_formatTimestamp(timestamp)}'),
                    Text('⏰ Hết hạn: ${_formatTimestamp(expiresAt)}'),
                    Text('📊 Trạng thái: ${_formatDuration(expiresAt)}'),
                    if (data is List) Text('📦 Số lượng: ${data.length} mục'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Dữ liệu:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Data Preview
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _formatJsonPreview(data),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Xóa cache này'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache(key);
            },
          ),
        ],
      ),
    );
  }

  String _formatJsonPreview(dynamic data) {
    try {
      if (data is List) {
        if (data.isEmpty) return '[]';
        // Show first 3 items preview
        final preview = data.take(3).map((e) {
          if (e is Map) {
            return e.entries.take(5).map((entry) => '  "${entry.key}": ${_truncate(entry.value.toString(), 50)}').join(',\n');
          }
          return '  ${_truncate(e.toString(), 100)}';
        }).join('\n},\n{\n');
        
        return '[\n{\n$preview\n}\n${data.length > 3 ? '... và ${data.length - 3} mục khác' : ''}]';
      }
      return data.toString();
    } catch (e) {
      return 'Không thể hiển thị dữ liệu';
    }
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Xóa toàn bộ cache?'),
          ],
        ),
        content: const Text(
          'Hành động này sẽ xóa tất cả dữ liệu cache, bao gồm cả session đăng nhập. Bạn sẽ cần đăng nhập lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache(null);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }
}