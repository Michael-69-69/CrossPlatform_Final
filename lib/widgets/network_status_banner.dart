// widgets/network_status_banner.dart
import 'package:flutter/material.dart';
import '../services/network_service.dart';

class NetworkStatusBanner extends StatefulWidget {
  final Widget child;

  const NetworkStatusBanner({super.key, required this.child});

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  NetworkStatus _status = NetworkStatus.unknown;

  @override
  void initState() {
    super.initState();
    _status = NetworkService().currentStatus;
    
    NetworkService().networkStatusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show banner only when offline
        if (_status == NetworkStatus.offline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Chế độ ngoại tuyến - Dữ liệu từ bộ nhớ đệm',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}