import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'models/location_history.dart';
import 'services/location_history_service.dart';

class LocationHistoryPage extends StatefulWidget {
  const LocationHistoryPage({Key? key}) : super(key: key);

  @override
  State<LocationHistoryPage> createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {
  final LocationHistoryService _service = LocationHistoryService();
  List<LocationRoute> _routes = [];
  LocationHistoryStats? _stats;
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, week, month, year
  LocationRoute? _selectedRoute;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        return _routes.where((route) => route.startTime.isAfter(weekAgo)).toList();
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return _routes.where((route) => route.startTime.isAfter(monthAgo)).toList();
      case 'year':
        final yearAgo = DateTime(now.year - 1, now.month, now.day);
        return _routes.where((route) => route.startTime.isAfter(yearAgo)).toList();
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
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
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
                    const Text(
                      'Lịch sử di chuyển',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Stats Card
              if (_stats != null) _buildStatsCard(),

              // Filter Buttons
              _buildFilterButtons(),

              // Routes List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildRoutesList(),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
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
    );
  }

  Widget _buildFilterButton(String text, String value) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? const Color(0xFF667eea) : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildRoutesList() {
    if (_filteredRoutes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Chưa có lịch sử di chuyển',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Các lộ trình của bạn sẽ xuất hiện ở đây',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredRoutes.length,
      itemBuilder: (context, index) {
        final route = _filteredRoutes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteCard(LocationRoute route) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.route,
            color: Color(0xFF667eea),
          ),
        ),
        title: Text(
          route.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(route.startTime),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
        trailing: IconButton(
          icon: const Icon(Icons.visibility),
          onPressed: () => _showRouteDetails(route),
        ),
        onTap: () => _showRouteDetails(route),
      ),
    );
  }

  void _showRouteDetails(LocationRoute route) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteDetailsPage(route: route),
      ),
    );
  }
}

class RouteDetailsPage extends StatefulWidget {
  final LocationRoute route;

  const RouteDetailsPage({
    Key? key,
    required this.route,
  }) : super(key: key);

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
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
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
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        ),
                        Marker(
                          markerId: const MarkerId('end'),
                          position: widget.route.points.last.toLatLng(),
                          infoWindow: const InfoWindow(title: 'Điểm kết thúc'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
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
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
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