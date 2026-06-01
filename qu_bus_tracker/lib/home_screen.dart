/// Home screen with map and overlays
///
/// The primary app screen that shows the interactive map, active bus
/// markers, route filters, and UI overlays (search, details sheet).
/// Subscribes to `BusService`, `ConvexBusService`, and
/// `LocationService` to keep map markers and ETA information up to date.
///
/// Responsibilities:
/// - Render interactive Google Map and marker icons
/// - Manage UI sheets for route/bus details and lists
/// - Handle navigation to `BusDetailsScreen` and destination picker

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'destination_selection_screen.dart';
import 'bus_details_screen.dart';
import 'bus_service.dart';
import 'bus_models.dart';
import 'convex_bus_service.dart';
import 'location_service.dart';
import 'maps_config.dart';
import 'schedule_service.dart';
import 'schedule_arrival_pill.dart';
import 'live_bus_marker_icon.dart';
import 'bus_eta_helper.dart';

class HomeScreen extends StatefulWidget {
  final String gender;

  const HomeScreen({super.key, required this.gender});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(25.3700, 51.4831); // QU Campus center
  bool _isLoading = true;
  String? _selectedDestination;
  String? _selectedMarkerLocation; // Location of tapped marker
  final DraggableScrollableController _detailsSheetController = DraggableScrollableController();
  final DraggableScrollableController _busesListSheetController = DraggableScrollableController();
  bool _showAllBuses = false; // Toggle to show all live buses
  final Map<String, BitmapDescriptor> _busIconCache = {}; // Cache for bus icons by route color (key: color value as string)
  BitmapDescriptor? _stopIcon; // Cached custom stop icon (blue)
  BitmapDescriptor? _liveBusIcon;
  String? _focusedLiveBusId;
  final TextEditingController _searchController = TextEditingController();
  Map<String, String?> _stopGenders = {};
  Timer? _clockTimer;
  String _currentTime = '';
  final ScheduleService _scheduleService = ScheduleService();
  Map<String, List<int>> _stopSchedule = {};
  bool _isLoadingSchedule = false;

  // Qatar University campus bounds
  static const LatLng _quCenter = LatLng(25.376453, 51.488121);
  static const double _quZoom = 16.0;

  // Official QU campus locations (populated from BusService)
  Map<String, LatLng> _campusLocations = {};

  // Helper to check if stop should show for current gender
  bool _shouldShowStop(String stopName) {
    final gender = _stopGenders[stopName];
    if (gender == null) return true;
    if (gender == widget.gender) return true;
    return false;
  }

  void _updateClock() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    setState(() {
      _currentTime = '$hour:$minute $period';
    });
  }

  Future<void> _loadStopSchedule(String stopId) async {
  setState(() {
    _isLoadingSchedule = true;
    _stopSchedule = {};
  });

  print("REQUESTING STOP ID: $stopId");

  final scheduleData = await _scheduleService.getStopSchedule(stopId);

  if (scheduleData != null && mounted) {
    final nextBuses = _scheduleService.getNextBuses(scheduleData);
    setState(() {
      _stopSchedule = nextBuses;
      _isLoadingSchedule = false;
    });
  } else if (mounted) {
    print("NO DATA FOUND FOR: $stopId");
    setState(() {
      _isLoadingSchedule = false;
    });
  }
}

  Widget _buildScheduleContent() {
    if (_isLoadingSchedule) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B0000)),
          ),
        ),
      );
    }

    if (_stopSchedule.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No schedule data available',
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Buses',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C2C2C),
            ),
          ),
          const SizedBox(height: 12),
          ..._stopSchedule.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B0000),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((minutes) {
                      return ScheduleArrivalPill(
                        busTimeMinutes: minutes,
                        scheduleService: _scheduleService,
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    // Listen to details sheet controller to detect when fully closed
    _detailsSheetController.addListener(() {
      if (_detailsSheetController.size <= 0.01) {
        // Sheet is fully closed, ensure marker and destination are cleared
        if (mounted) {
          setState(() {
            _selectedMarkerLocation = null;
            _selectedDestination = null;
          });
        }
      }
    });
    // Defer initialization that depends on Inherited widgets / Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Initialize bus service
    try {
      final busService = Provider.of<BusService>(context, listen: false);
      // Load campus routes/stops and Convex live buses
      await busService.initializeCampusData();

      // Populate campus locations from BusService stops
      final stops = busService.getAllStops();
      if (stops.isNotEmpty) {
        final map = <String, LatLng>{};
        final genderMap = <String, String?>{};
        for (var s in stops) {
          map[s.name] = s.location;
          genderMap[s.name] = s.gender;
        }
        if (mounted) {
          setState(() {
            _campusLocations = map;
            _stopGenders = genderMap;
          });
        }
      }
    } catch (e) {
      // If provider isn't available or initialization fails, log and continue
      debugPrint('BusService init error: $e');
    }

    // Initialize Convex bus service
    try {
      final convexBusService = Provider.of<ConvexBusService>(context, listen: false);
      await convexBusService.initialize();
      LiveBusMarkerIcon.get().then((icon) {
        if (mounted) setState(() => _liveBusIcon = icon);
      });
    } catch (e) {
      debugPrint('ConvexBusService init error: $e');
    }

    // Get current location
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        if (!mounted) return;
        setState(() {
          _currentLocation = location;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error getting location: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // Zoom controls
  Future<void> _zoomIn() async {
    if (_mapController == null) return;
    try {
      await _mapController!.animateCamera(CameraUpdate.zoomIn());
    } catch (e) {
      debugPrint('Zoom in error: $e');
    }
  }

  Future<void> _zoomOut() async {
    if (_mapController == null) return;
    try {
      await _mapController!.animateCamera(CameraUpdate.zoomOut());
    } catch (e) {
      debugPrint('Zoom out error: $e');
    }
  }

  Future<void> _resetMapPosition() async {
    if (_mapController == null) return;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(
            target: _quCenter,
            zoom: _quZoom,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Reset map position error: $e');
    }
  }

  Future<void> _selectDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationSelectionScreen(gender: widget.gender),
      ),
    );

    if (result != null && result is Map) {
      final destination = result['destination'] as String?;
      if (destination != null && _campusLocations.containsKey(destination)) {
        setState(() {
          _selectedDestination = destination;
          // If a bus was selected, open the details sheet
          if (result['busId'] != null) {
            _selectedMarkerLocation = destination;
            // Wait for sheet to be created
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_detailsSheetController.isAttached && mounted) {
                _detailsSheetController.animateTo(
                  0.3,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        });
        
        // Animate to selected destination
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(_campusLocations[destination]!),
          );
        }
      }
    } else if (result != null && result is String) {
      // Backward compatibility: handle old string return format
      setState(() {
        _selectedDestination = result;
      });
      
      if (_mapController != null && _campusLocations.containsKey(result)) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_campusLocations[result]!),
        );
      }
    }
  }

  (String?, LatLng?) _resolveStopForEta() {
    final stopName = _selectedMarkerLocation ?? _selectedDestination;
    if (stopName == null || !_campusLocations.containsKey(stopName)) {
      return (null, null);
    }
    return (stopName, _campusLocations[stopName]);
  }

  void _clearLiveBusSelection() {
    final busId = _focusedLiveBusId;
    if (busId == null) return;
    setState(() => _focusedLiveBusId = null);
    BusEtaHelper.hideFromMap(
      mapController: _mapController,
      markerId: 'bus_$busId',
    );
  }

  void _onLiveBusTapped(Bus bus) {
    setState(() => _focusedLiveBusId = bus.id);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(bus.currentLocation, 18),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      BusEtaHelper.showOnMap(
        mapController: _mapController,
        markerId: 'bus_${bus.id}',
      );
    });

    final (stopName, _) = _resolveStopForEta();
    if (stopName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap a stop to see distance and arrival time'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget? _buildLiveBusEtaCard(ConvexBusService convexBusService) {
    if (_focusedLiveBusId == null) return null;

    Bus? bus;
    for (final candidate in convexBusService.liveBuses.values) {
      if (candidate.id == _focusedLiveBusId) {
        bus = candidate;
        break;
      }
    }
    if (bus == null) return null;

    final (stopName, stopLocation) = _resolveStopForEta();
    if (stopName == null || stopLocation == null) return null;

    final eta = BusEtaHelper.compute(bus.currentLocation, stopLocation);
    final busLabel = bus.id.contains('_')
        ? 'Bus ${bus.id.split('_').last}'
        : 'Bus ${bus.id}';

    return BusEtaMapCard(
      busLabel: busLabel,
      routeName: _getRouteName(bus.routeId),
      stopName: stopName,
      eta: eta,
      routeColor: _getRouteColorAsColor(bus.routeId),
      onClose: _clearLiveBusSelection,
    );
  }

  Set<Marker> _getMarkers(ConvexBusService convexBusService) {
    Set<Marker> markers = {};
    
    // Pre-create bus icons for all active buses (async operation, but we'll handle it)
    // Note: This will need to be handled differently since we can't await in getMarkers
    // We'll create icons on first use and cache them

    // Add current location marker
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
      ),
    );

    // Add destination marker if selected
    if (_selectedDestination != null && 
        _campusLocations.containsKey(_selectedDestination)) {
      markers.add(
        Marker(
          markerId: MarkerId('destination_$_selectedDestination'),
          position: _campusLocations[_selectedDestination]!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: _selectedDestination!,
            snippet: 'Your destination',
          ),
          onTap: () {
            final busService = Provider.of<BusService>(context, listen: false);
            final stop = busService.getAllStops().firstWhere(
              (s) => s.name == _selectedDestination,
              orElse: () => BusStop(
                id: _selectedDestination!,
                name: _selectedDestination!,
                description: '',
                location: _campusLocations[_selectedDestination]!,
                routes: [],
              ),
            );
            setState(() {
              _selectedMarkerLocation = _selectedDestination!;
              _showAllBuses = false;
            });
            _loadStopSchedule(stop.id);
            // Close buses list if open
            if (_busesListSheetController.isAttached) {
              _busesListSheetController.animateTo(
                0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
              );
            }
            // Open the details sheet (will be created in build if _selectedMarkerLocation is not null)
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_detailsSheetController.isAttached && mounted) {
                _detailsSheetController.animateTo(
                  0.3, // Initial height (30% of screen)
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
      );
    }

    // Add campus location markers (filtered by gender)
    for (String location in _campusLocations.keys) {
      if (location != _selectedDestination && _shouldShowStop(location)) {
        // Determine icon: use cached custom stop icon if available, otherwise use default hue and create the custom icon async
        BitmapDescriptor stopIcon = BitmapDescriptor.defaultMarkerWithHue(MapsConfig.campusMarkerHue);
        if (_stopIcon != null) {
          stopIcon = _stopIcon!;
        } else {
          // Create and cache stop icon asynchronously
          _createStopIcon().then((icon) {
            if (mounted) {
              setState(() {
                _stopIcon = icon;
              });
            }
          });
        }

        markers.add(
          Marker(
            markerId: MarkerId('campus_$location'),
            position: _campusLocations[location]!,
            icon: stopIcon,
            infoWindow: InfoWindow(
              title: location,
              snippet: 'Tap to select as destination',
            ),
onTap: () {
  final busService = Provider.of<BusService>(context, listen: false);

  final stop = busService.getAllStops().firstWhere(
    (s) => s.name == location,
  );

  print("STOP NAME: ${stop.name}");
  print("STOP ID: ${stop.id}");

  setState(() {
    _selectedMarkerLocation = location;
    _selectedDestination = location;
    _showAllBuses = false;
  });

  _loadStopSchedule(stop.id); // ✅ NOW CORRECT

  if (_busesListSheetController.isAttached) {
    _busesListSheetController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  Future.delayed(const Duration(milliseconds: 100), () {
    if (_detailsSheetController.isAttached && mounted) {
      _detailsSheetController.animateTo(
        0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}
          ),
        );
      }
    }

    // Live GPS buses — 🚌 at driver's real-time Convex location
    final busIcon = _liveBusIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    if (_liveBusIcon == null) {
      LiveBusMarkerIcon.get().then((icon) {
        if (mounted) setState(() => _liveBusIcon = icon);
      });
    }

    final (etaStopName, etaStopLocation) = _resolveStopForEta();

    for (final bus in convexBusService.liveBuses.values) {
      if (bus.status == BusStatus.running) {
        final routeName = _getRouteName(bus.routeId);
        BusEtaInfo? etaInfo;
        if (etaStopLocation != null) {
          etaInfo = BusEtaHelper.compute(bus.currentLocation, etaStopLocation);
        }

        markers.add(
          Marker(
            markerId: MarkerId('bus_${bus.id}'),
            position: bus.currentLocation,
            icon: busIcon,
            flat: true,
            anchor: const Offset(0.5, 0.5),
            infoWindow: BusEtaHelper.buildInfoWindow(
              bus: bus,
              routeName: routeName,
              stopName: etaStopName,
              eta: etaInfo,
            ),
            onTap: () => _onLiveBusTapped(bus),
          ),
        );
      }
    }

    return markers;
  }

  // Helper methods to get route information
  double _getRouteColor(String routeId) {
    final busService = Provider.of<BusService>(context, listen: false);
    final routes = busService.getAllRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: const Duration(minutes: 0),
      ),
    );
    
    // Map hex colors to BitmapDescriptor hue values
    switch (route.color.toUpperCase()) {
      case '#1976D2': // Blue Route
        return BitmapDescriptor.hueBlue;
      case '#42A5F5': // Light Blue Route
        return BitmapDescriptor.hueCyan;
      case '#388E3C': // Dark Green Route
        return BitmapDescriptor.hueGreen;
      case '#66BB6A': // Light Green Route
        return BitmapDescriptor.hueGreen;
      case '#7B1FA2': // Purple Route
        return BitmapDescriptor.hueViolet;
      case '#C2185B': // Pink Route
        return BitmapDescriptor.hueRose;
      case '#F57C00': // Orange Route
        return BitmapDescriptor.hueOrange;
      case '#212121': // Black Line
        return BitmapDescriptor.hueRed; // Use red for black line (dark marker)
      case '#FAFAFA': // White Line
        return BitmapDescriptor.hueYellow;
      case '#5D4037': // Brown Line
        return BitmapDescriptor.hueRed;
      case '#8D6E63': // Maroon Line
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  String _getRouteName(String routeId) {
    final busService = Provider.of<BusService>(context, listen: false);
    final routes = busService.getAllRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: routeId,
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: const Duration(minutes: 0),
      ),
    );
    return route.name;
  }

  // Helper method to get route color as Color object
  Color _getRouteColorAsColor(String routeId) {
    final busService = Provider.of<BusService>(context, listen: false);
    final routes = busService.getAllRoutes();
    final route = routes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: const Duration(minutes: 0),
      ),
    );
    
    // Parse hex color directly
    try {
      return Color(int.parse(route.color.replaceFirst('#', '0xFF')));
    } catch (e) {
      // Fallback to a default color if parsing fails
      return const Color(0xFF666666);
    }
  }

  // Create custom bus icon bitmap (double size)
  Future<BitmapDescriptor> _createBusIcon(Color routeColor) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 160.0; // Icon size (double)
    
    // Draw bus body (rectangle with rounded corners)
    final busPaint = Paint()
      ..color = routeColor
      ..style = PaintingStyle.fill;
    
    final busRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(20, 40, 120, 80),
      const Radius.circular(16),
    );
    canvas.drawRRect(busRect, busPaint);
    
    // Draw bus windows
    final windowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Front window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30, 50, 30, 24),
        const Radius.circular(6),
      ),
      windowPaint,
    );
    
    // Back window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(100, 50, 30, 24),
        const Radius.circular(6),
      ),
      windowPaint,
    );
    
    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 130), 12, wheelPaint);
    canvas.drawCircle(const Offset(110, 130), 12, wheelPaint);
    
    // Draw white center for wheels
    final wheelCenterPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(const Offset(50, 130), 6, wheelCenterPaint);
    canvas.drawCircle(const Offset(110, 130), 6, wheelCenterPaint);
    
    // Convert to image
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  // Create a bus-stop icon (blue pin with white bus symbol) - larger size
  Future<BitmapDescriptor> _createStopIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 128.0; // doubled

    // Draw blue pin circle
    final pinPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size/2, size/2 - 12), 32, pinPaint);

    // Draw small white bus rectangle inside the pin
    final busPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size/2 - 20, size/2 - 24, 40, 24),
        const Radius.circular(6),
      ),
      busPaint,
    );

    // Draw the pin tail (triangle)
    final tailPaint = Paint()..color = Colors.blue;
    final path = Path()
      ..moveTo(size/2 - 16, size/2 + 16)
      ..lineTo(size/2 + 16, size/2 + 16)
      ..lineTo(size/2, size - 8)
      ..close();
    canvas.drawPath(path, tailPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B0000)),
                  ),
                )
              : Consumer<ConvexBusService>(
                  builder: (context, convexBusService, child) {
                    final etaCard = _buildLiveBusEtaCard(convexBusService);

                    return Stack(
                      children: [
                        GoogleMap(
                          mapType: MapType.hybrid,
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: const CameraPosition(
                            target: _quCenter,
                            zoom: _quZoom,
                          ),
                          markers: _getMarkers(convexBusService),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          onTap: (LatLng position) {
                            final busId = _focusedLiveBusId;
                            setState(() {
                              _selectedDestination = null;
                              _selectedMarkerLocation = null;
                              _focusedLiveBusId = null;
                            });
                            if (busId != null) {
                              BusEtaHelper.hideFromMap(
                                mapController: _mapController,
                                markerId: 'bus_$busId',
                              );
                            }
                            if (_detailsSheetController.isAttached) {
                              _detailsSheetController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeIn,
                              );
                            }
                          },
                        ),
                        if (etaCard != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 72,
                            child: etaCard,
                          ),
                      ],
                    );
                  },
                ),

          // Clock showing current time (small rectangle above destination button)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Destination Selection Button (moved to top)
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _selectDestination,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B0000).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF8B0000),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedDestination ?? 'Where do you want to go?',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                              if (_selectedDestination == null)
                                const Text(
                                  'Select your destination on campus',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF666666),
                                  ),
                                )
                              else
                                Text(
                                  'Destination selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF8B0000),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF8B0000),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Show All Live Buses Button (bottom center) - ALWAYS visible
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: _showAllBuses ? const Color(0xFF8B0000) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      setState(() {
                        _showAllBuses = !_showAllBuses;
                      });
                      // Animate sheet up/down
                      if (_showAllBuses) {
                        _busesListSheetController.animateTo(
                          0.4, // 40% of screen height
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      } else {
                        _busesListSheetController.animateTo(
                          0.0, // Hide sheet
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAllBuses ? Icons.close : Icons.search,
                            color: _showAllBuses ? Colors.white : const Color(0xFF8B0000),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showAllBuses ? 'Hide Bus-Stops' : 'Search Bus-Stops',
                            style: TextStyle(
                              color: _showAllBuses ? Colors.white : const Color(0xFF8B0000),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Draggable Details Sheet (slides up when marker is tapped) - layered above button
          if (_selectedMarkerLocation != null)
            DraggableScrollableSheet(
              controller: _detailsSheetController,
              initialChildSize: 0.3, // 30% of screen height initially
              minChildSize: 0.0, // Allow full close
              maxChildSize: 0.95, // Maximum 95% (almost fullscreen)
              snap: true,
              snapSizes: const [0.0, 0.3, 0.6, 0.95], // Snap points including 0.0 for full close
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_bus,
                              color: Color(0xFF8B0000),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Routes to $_selectedMarkerLocation',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF8B0000)),
                              onPressed: () {
                                // IMMEDIATELY clear ALL state - this must happen first
                                _selectedMarkerLocation = null;
                                _selectedDestination = null;
                                
                                // Force setState to rebuild UI immediately
                                setState(() {
                                  // State already cleared above for immediate effect
                                });
                                
                                // Close the sheet with animation
                                if (_detailsSheetController.isAttached) {
                                  _detailsSheetController.animateTo(
                                    0.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeIn,
                                  );
                                }
                                
                                // Ensure state is still cleared after rebuild
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _selectedMarkerLocation = null;
                                    _selectedDestination = null;
                                    setState(() {
                                      // Force rebuild
                                    });
                                  }
                                });
                                
                                // Final check after animation
                                Future.delayed(const Duration(milliseconds: 350), () {
                                  if (mounted) {
                                    _selectedMarkerLocation = null;
                                    _selectedDestination = null;
                                    setState(() {
                                      // Final cleanup
                                    });
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Quick info
                              const Text(
                                'Bus Route 1: 5 min • Bus Route 2: 8 min',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Full details button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BusDetailsScreen(
                                          destination: _selectedMarkerLocation!,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B0000),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Full Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              // Schedule display
                              _buildScheduleContent(),
                              const SizedBox(height: 20),
                              // Additional route information can go here
                              Text(
                                'Location: $_selectedMarkerLocation',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Zoom controls (+ / -) at top right
          Positioned(
            top: 190,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Color(0xFF8B0000)),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Color(0xFF8B0000)),
                ),
              ],
            ),
          ),

          // Reset map position button (bottom right, same level as search bus stops)
          Positioned(
            bottom: 30,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'reset_map',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _resetMapPosition,
              child: const Icon(Icons.my_location, color: Color(0xFF8B0000)),
            ),
          ),

// Search Bus Stops Sheet (slides up from bottom)
          DraggableScrollableSheet(
            controller: _busesListSheetController,
            initialChildSize: 0.0,
            minChildSize: 0.0,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.5, 0.85],
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_busesListSheetController.isAttached) {
                            final currentSize = _busesListSheetController.size;
                            if (currentSize < 0.6) {
                              _busesListSheetController.animateTo(
                                0.85,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            } else {
                              _busesListSheetController.animateTo(
                                0.5,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeIn,
                              );
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 8),
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Color(0xFF8B0000),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Search Bus Stops',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C2C2C),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF8B0000)),
                              onPressed: () {
                                setState(() {
                                  _showAllBuses = false;
                                });
                                _busesListSheetController.animateTo(
                                  0.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeIn,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a bus stop...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      Expanded(
                        child: Consumer<BusService>(
                          builder: (context, busService, child) {
                            final allStops = busService.getAllStops();
                            final searchQuery = _searchController.text;
                            
                            final filteredStops = allStops.where((stop) {
                              final matchesSearch = searchQuery.isEmpty || 
                                  stop.name.toLowerCase().contains(searchQuery.toLowerCase());
                              return matchesSearch && _shouldShowStop(stop.name);
                            }).toList();

                            if (filteredStops.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No bus stops found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredStops.length,
                              itemBuilder: (context, index) {
                                final stop = filteredStops[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Color(0xFF8B0000),
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      stop.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      stop.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedDestination = stop.name;
                                        _selectedMarkerLocation = stop.name;
                                        _showAllBuses = false;
                                      });
                                      _loadStopSchedule(stop.id);
                                      if (_campusLocations.containsKey(stop.name)) {
                                        _mapController?.animateCamera(
                                          CameraUpdate.newLatLng(_campusLocations[stop.name]!),
                                        );
                                      }
                                      _busesListSheetController.animateTo(
                                        0.0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeIn,
                                      );
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        if (_detailsSheetController.isAttached && mounted) {
                                          _detailsSheetController.animateTo(
                                            0.3,
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOut,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    _detailsSheetController.dispose();
    _busesListSheetController.dispose();
    super.dispose();
  }
}

