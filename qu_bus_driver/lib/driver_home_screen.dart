import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_service.dart';
import 'convex_service.dart';
import 'driver_models.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _busIdController = TextEditingController();
  final TextEditingController _routeIdController = TextEditingController();
  
  bool _isTracking = false;
  String _selectedRoute = 'blue_route';
  StreamSubscription<void>? _locationBroadcastSubscription;
  StreamSubscription<Position>? _locationStreamSubscription;
  DateTime? _lastPublishAt;
  String? _lastPublishedCoords;

  // Available routes for selection
  final List<Map<String, String>> _availableRoutes = [
    {'id': 'blue_route', 'name': 'Blue Route', 'description': 'Female Classrooms → Women\'s Activity → Library → Business'},
    {'id': 'light_blue_route', 'name': 'Light Blue Route', 'description': 'Female Classrooms → Women\'s Activity → Engineering'},
    {'id': 'dark_green_route', 'name': 'Dark Green Route', 'description': 'Female Classrooms → Women\'s Activity → Education'},
    {'id': 'light_green_route', 'name': 'Light Green Route', 'description': 'Female Classrooms → Women\'s Activity → Law'},
    {'id': 'purple_route', 'name': 'Purple Route', 'description': 'Female Classrooms → Al Razi → Ibn Al Baitar'},
    {'id': 'pink_route', 'name': 'Pink Route', 'description': 'Women\'s Activity → Al Razi → Ibn Al Baitar'},
    {'id': 'orange_route', 'name': 'Orange Route', 'description': 'Tamyuz Simulation Center → Engineering → Law'},
    {'id': 'black_line', 'name': 'Black Line (Main Loop)', 'description': 'Complete campus tour - 25 minutes'},
    {'id': 'white_line', 'name': 'White Line (Inner Loop)', 'description': 'Inner campus loop - 18 minutes'},
    {'id': 'brown_line', 'name': 'Brown Line (Research & Sports)', 'description': 'Research complex and sports facilities - 15 minutes'},
    {'id': 'maroon_line', 'name': 'Maroon Line (Express)', 'description': 'Quick express route - 8 minutes'},
    {'id': 'mhostel1', 'name': 'Male Hostel Bus 1', 'description': 'Male Hostel ↔ Metro'},
    {'id': 'mhostel2', 'name': 'Male Hostel Bus 2', 'description': 'Male Hostel ↔ Metro'},
    {'id': 'mhostel3', 'name': 'Male Hostel Bus 3', 'description': 'Male Hostel ↔ Metro'},
    {'id': 'fhostela', 'name': 'Female Hostel Bus A', 'description': 'Female Hostel ↔ Metro'},
    {'id': 'fhostelb', 'name': 'Female Hostel Bus B', 'description': 'Female Hostel ↔ Metro'},
    {'id': 'fhostelc', 'name': 'Female Hostel Bus C', 'description': 'Female Hostel ↔ Metro'},
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeConvex();
  }

  Future<void> _initializeConvex() async {
    try {
      final convexService = Provider.of<ConvexService>(context, listen: false);
      await convexService.initialize();
    } catch (e) {
      debugPrint('Error initializing Convex in UI: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convex connection issue. GPS tracking requires a live connection.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();
  }

  Future<void> _startTracking() async {
    if (_driverNameController.text.isEmpty || _busIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in driver name and bus ID'),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
      return;
    }

    try {
      final locationService = Provider.of<LocationService>(context, listen: false);

      // Start real GPS tracking
      try {
        await locationService.startLocationTracking();
      } catch (e) {
        debugPrint('Location tracking error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location tracking failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isTracking = true;
      });

      _locationStreamSubscription?.cancel();
      _locationStreamSubscription = locationService.onLocation.listen(
        _onLivePosition,
      );

      await _publishCurrentLocation();
      _startLocationBroadcast();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location tracking started'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error starting tracking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onLivePosition(Position position) {
    if (!_isTracking) return;

    final now = DateTime.now();
    if (_lastPublishAt != null &&
        now.difference(_lastPublishAt!) < const Duration(seconds: 1)) {
      return;
    }

    unawaited(_publishPosition(position));
  }

  Future<void> _publishCurrentLocation() async {
    if (!_isTracking) return;

    final locationService = Provider.of<LocationService>(context, listen: false);
    final location = locationService.currentLocation ??
        await locationService.getCurrentLocation();

    if (location == null) {
      debugPrint('No GPS fix yet — skipping Convex publish');
      return;
    }

    await _publishPosition(location);
  }

  Future<void> _publishPosition(Position location) async {
    if (!_isTracking) return;

    if (location.latitude == 0 && location.longitude == 0) {
      debugPrint('Ignoring invalid 0,0 GPS fix');
      return;
    }

    final convexService = Provider.of<ConvexService>(context, listen: false);

    final busData = BusLocationData(
      busId: _busIdController.text,
      driverName: _driverNameController.text,
      routeId: _selectedRoute,
      latitude: location.latitude,
      longitude: location.longitude,
      timestamp: DateTime.now(),
      status: BusStatus.running,
    );

    await convexService.sendBusLocation(busData);
    _lastPublishAt = DateTime.now();
    _lastPublishedCoords =
        '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';

    if (mounted) setState(() {});

    debugPrint(
      'Published live location: ${location.latitude}, ${location.longitude} '
      '(accuracy ${location.accuracy.toStringAsFixed(0)}m)',
    );
  }

  void _startLocationBroadcast() {
    _locationBroadcastSubscription?.cancel();
    _locationBroadcastSubscription =
        Stream.periodic(const Duration(seconds: 2)).listen((_) async {
      if (_isTracking) {
        await _publishCurrentLocation();
      }
    });
  }

  Future<void> _stopTracking() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final convexService = Provider.of<ConvexService>(context, listen: false);

    _locationBroadcastSubscription?.cancel();
    _locationBroadcastSubscription = null;
    _locationStreamSubscription?.cancel();
    _locationStreamSubscription = null;

    await locationService.stopLocationTracking();
    await convexService.removeBus(_busIdController.text);

    setState(() {
      _isTracking = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location tracking stopped'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QU Bus Driver',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Driver Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B0000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _driverNameController,
                      decoration: const InputDecoration(
                        labelText: 'Driver Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person, color: Color(0xFF8B0000)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _busIdController,
                      decoration: const InputDecoration(
                        labelText: 'Bus ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_bus, color: Color(0xFF8B0000)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Route Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Route',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B0000),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRoute,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.route, color: Color(0xFF8B0000)),
                      ),
                      isExpanded: true,
                      selectedItemBuilder: (BuildContext context) {
                        return _availableRoutes.map((route) {
                          return Text(
                            route['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        }).toList();
                      },
                      items: _availableRoutes.map((route) {
                        return DropdownMenuItem<String>(
                          value: route['id'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                route['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                route['description']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoute = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location Status Card
            Consumer2<LocationService, ConvexService>(
              builder: (context, locationService, convexService, child) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B0000),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          'Location Tracking',
                          locationService.isTracking ? 'Active' : 'Inactive',
                          locationService.isTracking ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow(
                          'Convex Connection',
                          convexService.isConnected ? 'Connected' : 'Disconnected',
                          convexService.isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        if (locationService.currentLocation != null)
                          _buildStatusRow(
                            'GPS fix',
                            '${locationService.currentLocation!.latitude.toStringAsFixed(6)}, '
                            '${locationService.currentLocation!.longitude.toStringAsFixed(6)} '
                            '(±${locationService.currentLocation!.accuracy.toStringAsFixed(0)}m)',
                            Colors.blue,
                          ),
                        if (_lastPublishedCoords != null) ...[
                          const SizedBox(height: 8),
                          _buildStatusRow(
                            'Sent to students',
                            _lastPublishedCoords!,
                            Colors.green,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? null : _startTracking,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTracking ? _stopTracking : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Fill in your driver name and bus ID\n'
                      '2. Select the route you are driving\n'
                      '3. Tap "Start Tracking" to begin sending location data\n'
                      '4. Students will see your bus location in real-time\n'
                      '5. Tap "Stop Tracking" when your shift ends',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _locationBroadcastSubscription?.cancel();
    _locationStreamSubscription?.cancel();
    _driverNameController.dispose();
    _busIdController.dispose();
    _routeIdController.dispose();
    super.dispose();
  }
}
