import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/toast_service.dart';

class ProUpgradePage extends StatefulWidget {
  const ProUpgradePage({super.key});

  @override
  State<ProUpgradePage> createState() => _ProUpgradePageState();
}

class _ProUpgradePageState extends State<ProUpgradePage> {
  bool _processing = false;
  bool _alreadyPro = false;

  @override
  void initState() {
    super.initState();
    _checkPro();
  }

  Future<void> _checkPro() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final svc = UserService();
      final active = await svc.isProActive(uid);
      if (mounted) setState(() => _alreadyPro = active);
    } catch (_) {}
  }

  Future<void> _purchaseOneMonth() async {
    if (_processing) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ToastService.show(
        context,
        message: 'Không tìm thấy người dùng.',
        type: AppToastType.error,
      );
      return;
    }
    setState(() => _processing = true);
    try {
      // Placeholder: Thực hiện thanh toán tại đây.
      // Sau khi thanh toán thành công, kích hoạt Pro.
      final svc = UserService();
      await svc.setProActive(uid, true);
      if (mounted) {
        ToastService.show(
          context,
          message: 'Đã mua thành công gói Pro 1 tháng!',
          type: AppToastType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ToastService.show(
        context,
        message: 'Thanh toán thất bại: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nâng cấp Pro')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Gói Pro 1 tháng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Quyền lợi:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text('• Chia sẻ địa điểm yêu thích trong chat'),
                  Text('• Lưu địa điểm yêu thích không giới hạn'),
                  Text('• Ưu tiên cập nhật vị trí'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_alreadyPro)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10b981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tài khoản của bạn đã là Pro.',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _alreadyPro || _processing
                    ? null
                    : _purchaseOneMonth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_processing ? 'Đang xử lý...' : 'Mua gói 1 tháng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
