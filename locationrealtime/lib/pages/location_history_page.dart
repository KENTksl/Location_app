import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/location_history.dart';
import '../services/location_history_service.dart';
import '../widgets/empty_states.dart';

class LocationHistoryPage extends StatefulWidget {
  final LocationHistoryService? service;

  const LocationHistoryPage({super.key, this.service});

  @override
  State<LocationHistoryPage> createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {
  late final LocationHistoryService _service;
  List<LocationRoute> _routes = [];
  LocationHistoryStats? _stats;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, week, month, year
  int? _retentionDays; // null: tắt tự xóa
  final ScrollController _filterScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? LocationHistoryService();
    _loadData();
    _loadRetention();
  }

  Future<void> _loadRetention() async {
    final days = await _service.getRetentionDays();
    setState(() {
      _retentionDays = days;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load routes từ local storage
      final routes = await _service.getRoutesLocally();

      // Load routes từ Firebase
      final firebaseRoutes = await _service.getRoutesFromFirebase();

      // Merge và sort theo thời gian
      final allRoutes = [...routes, ...firebaseRoutes];
      allRoutes.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Remove duplicates
      final uniqueRoutes = <LocationRoute>[];
      final seenIds = <String>{};

      for (final route in allRoutes) {
        if (!seenIds.contains(route.id)) {
          uniqueRoutes.add(route);
          seenIds.add(route.id);
        }
      }

      setState(() {
        _routes = uniqueRoutes;
        _stats = _service.calculateStats(uniqueRoutes);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading location history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<LocationRoute> get _filteredRoutes {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return _routes
            .where((route) => route.startTime.isAfter(weekAgo))
            .toList();
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return _routes
            .where((route) => route.startTime.isAfter(monthAgo))
            .toList();
      case 'year':
        final yearAgo = DateTime(now.year - 1, now.month, now.day);
        return _routes
            .where((route) => route.startTime.isAfter(yearAgo))
            .toList();
      default:
        return _routes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Lịch sử di chuyển',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _showRetentionSettings,
                        tooltip: 'Cài đặt tự xóa',
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Card
              if (_stats != null) SliverToBoxAdapter(child: _buildStatsCard()),

              // Filter Buttons
              SliverToBoxAdapter(child: _buildFilterButtons()),

              // Routes Sliver (list/empty/loading)
              _buildRoutesSliver(),
            ],
          ),
        ),
      ),
    );
  }

  void _showRetentionSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final options = <Map<String, dynamic>>[
          {'label': '7 ngày', 'days': 7},
          {'label': '1 tháng', 'days': 30},
          {'label': '3 tháng', 'days': 90},
          {'label': '6 tháng', 'days': 180},
          {'label': '12 tháng', 'days': 365},
          {'label': 'Tùy chỉnh', 'days': null},
        ];

        int? selectedDays = _retentionDays;
        final TextEditingController customController = TextEditingController(
          text: selectedDays == null ? (_retentionDays?.toString() ?? '') : '',
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isCustom = selectedDays == null;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtle top divider shadow
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tự động xóa lộ trình',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...options.map(
                    (opt) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ), // 12pt spacing between options
                      child: RadioListTile<int?>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(opt['label'] as String),
                        value: opt['days'] as int?,
                        groupValue: selectedDays,
                        onChanged: (value) {
                          setModalState(() {
                            selectedDays = value;
                            if (value != null) {
                              customController.text = '';
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (selectedDays == null) ...[
                    const SizedBox(height: 8),
                    const Text('Nhập số ngày giữ lại (ví dụ: 45):'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Số ngày',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCDCDC),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDCDCDC),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {});
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Đóng'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          int? daysToSave = selectedDays;
                          if (daysToSave == null) {
                            final parsed = int.tryParse(customController.text);
                            if (parsed == null || parsed <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập số ngày hợp lệ'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            daysToSave = parsed;
                          }

                          await _service.setRetentionDays(daysToSave);
                          await _service.purgeOldRoutes(days: daysToSave);
                          await _loadRetention();
                          await _loadData();
                          if (context.mounted) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã cập nhật cài đặt tự xóa'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Lưu'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(
                'Tổng quãng đường',
                '${_stats!.totalDistance.toStringAsFixed(1)} km',
                Icons.route,
                Colors.blue,
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                'Tổng thời gian',
                '${_stats!.totalDuration.inHours}h ${_stats!.totalDuration.inMinutes % 60}m',
                Icons.access_time,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem(
                'Tốc độ TB',
                '${_stats!.averageSpeed.toStringAsFixed(1)} km/h',
                Icons.speed,
                Colors.orange,
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                'Số lộ trình',
                '${_stats!.totalRoutes}',
                Icons.map,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748b)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Scrollbar(
        controller: _filterScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _filterScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterButton('Tất cả', 'all'),
              const SizedBox(width: 10),
              _buildFilterButton('Tuần này', 'week'),
              const SizedBox(width: 10),
              _buildFilterButton('Tháng này', 'month'),
              const SizedBox(width: 10),
              _buildFilterButton('Năm nay', 'year'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String text, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8E6CF2).withOpacity(0.7)
                : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? const Color(0xFF667eea) : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRoutesSliver() {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_filteredRoutes.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: EmptyStateTravelHistoryEmpty()),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final route = _filteredRoutes[index];
        return _buildRouteCard(route);
      }, childCount: _filteredRoutes.length),
    );
  }

  Widget _buildRouteCard(LocationRoute route) {
    // Tạo tên route đúng
    String routeName = route.name;
    if (routeName == 'Lộ trình đã ghi' || routeName == 'Temp') {
      routeName = _service.generateRouteName(route);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.route, color: Color(0xFF667eea)),
            ),
            const SizedBox(width: 15),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    routeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(route.startTime),
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Distance and Speed
                  Row(
                    children: [
                      Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${route.totalDistance.toStringAsFixed(2)} km',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.speed, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${route.averageSpeed.toStringAsFixed(1)} km/h',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Actions (gộp vào menu ...)
            PopupMenuButton<String>(
              tooltip: 'Tùy chọn',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _showRouteDetails(route);
                    break;
                  case 'rename':
                    _renameRoute(route);
                    break;
                  case 'delete':
                    _deleteRoute(route);
                    break;
                  default:
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: const [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('Xem chi tiết'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: const [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Đổi tên'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: const [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteDetails(LocationRoute route) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RouteDetailsPage(route: route)),
    );
  }

  void _deleteRoute(LocationRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lộ trình'),
        content: Text('Bạn có chắc muốn xóa lộ trình "${route.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteRoute(route.id);
              _loadData(); // Reload data
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa lộ trình'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _renameRoute(LocationRoute route) {
    final controller = TextEditingController(text: route.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên lộ trình'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập tên mới',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tên lộ trình không được để trống'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _service.renameRoute(route.id, newName);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã đổi tên lộ trình'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class RouteDetailsPage extends StatefulWidget {
  final LocationRoute route;

  const RouteDetailsPage({super.key, required this.route});

  @override
  State<RouteDetailsPage> createState() => _RouteDetailsPageState();
}

class _RouteDetailsPageState extends State<RouteDetailsPage> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _createRoutePolyline();
  }

  void _createRoutePolyline() {
    if (widget.route.points.length < 2) return;

    final polyline = Polyline(
      polylineId: PolylineId(widget.route.id),
      points: widget.route.latLngPoints,
      color: const Color(0xFF667eea),
      width: 5,
    );

    setState(() {
      _polylines = {polyline};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.route.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Route Info Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildDetailItem(
                          'Khoảng cách',
                          '${widget.route.totalDistance.toStringAsFixed(2)} km',
                          Icons.straighten,
                        ),
                        const SizedBox(width: 20),
                        _buildDetailItem(
                          'Thời gian',
                          '${widget.route.totalDuration.inHours}h ${widget.route.totalDuration.inMinutes % 60}m',
                          Icons.access_time,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildDetailItem(
                          'Tốc độ TB',
                          '${widget.route.averageSpeed.toStringAsFixed(1)} km/h',
                          Icons.speed,
                        ),
                        const SizedBox(width: 20),
                        _buildDetailItem(
                          'Số điểm',
                          '${widget.route.points.length}',
                          Icons.location_on,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Map
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.route.points.first.toLatLng(),
                        zoom: 15,
                      ),
                      polylines: _polylines,
                      markers: {
                        Marker(
                          markerId: const MarkerId('start'),
                          position: widget.route.points.first.toLatLng(),
                          infoWindow: const InfoWindow(title: 'Điểm bắt đầu'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                        ),
                        Marker(
                          markerId: const MarkerId('end'),
                          position: widget.route.points.last.toLatLng(),
                          infoWindow: const InfoWindow(title: 'Điểm kết thúc'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
                      },
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _fitBounds();
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF667eea), size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _fitBounds() {
    if (widget.route.points.isEmpty || _mapController == null) return;

    final bounds = _calculateBounds();
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  LatLngBounds _calculateBounds() {
    double minLat = widget.route.points.first.latitude;
    double maxLat = widget.route.points.first.latitude;
    double minLng = widget.route.points.first.longitude;
    double maxLng = widget.route.points.first.longitude;

    for (final point in widget.route.points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
