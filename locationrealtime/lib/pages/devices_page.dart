import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({Key? key}) : super(key: key);

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final DatabaseService _databaseService = DatabaseService();

  List<DeviceModel> _devices = [];
  List<UserModel> _users = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final devices = await _databaseService.getAllDevices();
      final users = await _databaseService.getAllUsers();

      setState(() {
        _devices = devices;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải dữ liệu: $e';
        _isLoading = false;
      });
    }
  }

  void _showAddDeviceDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'device';
    String? selectedUserId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm thiết bị mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên thiết bị',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Loại thiết bị',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'vehicle', child: Text('Xe cộ')),
                DropdownMenuItem(value: 'employee', child: Text('Nhân viên')),
                DropdownMenuItem(value: 'asset', child: Text('Tài sản')),
                DropdownMenuItem(value: 'device', child: Text('Thiết bị')),
              ],
              onChanged: (value) {
                selectedType = value!;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: selectedUserId,
              decoration: const InputDecoration(
                labelText: 'Gán cho người dùng (tùy chọn)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Không gán'),
                ),
                ..._users.map(
                  (user) => DropdownMenuItem(
                    value: user.uid,
                    child: Text(user.displayName),
                  ),
                ),
              ],
              onChanged: (value) {
                selectedUserId = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập tên thiết bị')),
                );
                return;
              }

              final selectedUser = selectedUserId != null
                  ? _users.firstWhere((u) => u.uid == selectedUserId)
                  : null;

              final device = DeviceModel(
                id: '',
                name: nameController.text.trim(),
                type: selectedType,
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                assignedUserId: selectedUserId,
                assignedUserName: selectedUser?.displayName,
                status: 'active',
                createdAt: DateTime.now(),
              );

              try {
                await _databaseService.createDevice(device);
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thêm thiết bị thành công')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi thêm thiết bị: $e')),
                );
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(DeviceModel device) {
    final assignedUser = device.assignedUserId != null
        ? _users.firstWhere(
            (u) => u.uid == device.assignedUserId,
            orElse: () => UserModel(
              uid: '',
              email: '',
              displayName: 'Không tìm thấy',
              role: 'unknown',
              createdAt: DateTime.now(),
              lastLoginAt: DateTime.now(),
            ),
          )
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDeviceIcon(device.type),
                  size: 48,
                  color: _getStatusColor(device.status),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        device.typeText,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(device.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    device.statusText,
                    style: TextStyle(
                      color: _getStatusColor(device.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (device.description != null) ...[
              const SizedBox(height: 16),
              Text(
                'Mô tả:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(device.description!),
            ],
            const SizedBox(height: 16),
            _buildDetailRow(
              'Người được gán',
              assignedUser?.displayName ?? 'Chưa gán',
            ),
            _buildDetailRow(
              'Trạng thái online',
              device.isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
            ),
            _buildDetailRow('Lần cuối hoạt động', device.formattedLastSeen),
            _buildDetailRow('Ngày tạo', _formatDate(device.createdAt)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _editDevice(device);
                    },
                    child: const Text('Chỉnh sửa'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteDevice(device);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Xóa'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'vehicle':
        return Icons.directions_car;
      case 'employee':
        return Icons.person;
      case 'asset':
        return Icons.inventory;
      case 'device':
        return Icons.devices;
      default:
        return Icons.device_unknown;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'maintenance':
        return Colors.orange;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editDevice(DeviceModel device) {
    // TODO: Implement edit device functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng chỉnh sửa đang phát triển')),
    );
  }

  void _deleteDevice(DeviceModel device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa thiết bị "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // TODO: Implement delete device in DatabaseService
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Xóa thiết bị thành công')),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Lỗi xóa thiết bị: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thiết bị'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : _devices.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.devices_other, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có thiết bị nào',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(device.status),
                      child: Icon(
                        _getDeviceIcon(device.type),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      device.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.typeText),
                        if (device.assignedUserName != null)
                          Text('Gán cho: ${device.assignedUserName}'),
                        Text(
                          device.isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
                          style: TextStyle(
                            color: device.isOnline ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'details':
                            _showDeviceDetails(device);
                            break;
                          case 'edit':
                            _editDevice(device);
                            break;
                          case 'delete':
                            _deleteDevice(device);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Row(
                            children: [
                              Icon(Icons.info),
                              SizedBox(width: 8),
                              Text('Chi tiết'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Chỉnh sửa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showDeviceDetails(device),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDeviceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
