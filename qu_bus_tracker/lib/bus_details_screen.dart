/// Bus details screen
///
/// This file defines the `BusDetailsScreen` widget. It shows detailed
/// information for a single destination: a focused map with live bus
/// positions, available routes, arrival/ETA estimates, and recent stops.
/// The screen subscribes to `BusService` and `ConvexBusService`
/// (real-time) and reconciles data to present a stable, user-friendly view.
///
/// Responsibilities:
/// - Render focused map and route overlays
/// - Subscribe to live updates and keep arrival times consistent
/// - Provide navigation to related screens (home, destination selector)

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'bus_models.dart';
import 'bus_service.dart';
import 'convex_bus_service.dart';
import 'schedule_service.dart';
import 'schedule_arrival_pill.dart';
import 'live_bus_marker_icon.dart';
import 'bus_eta_helper.dart';

const Map<String, LatLng> stopCoordinates = {
  // I series
  'I09m': LatLng(25.376087457119596, 51.48069196590328),
  'I09f': LatLng(25.374783619645747, 51.481530834481795),

  'I10m': LatLng(25.37658898975716, 51.4828877414271),
  'I10f': LatLng(25.37560672476257, 51.48242239454162),

  'I11m': LatLng(25.377979388163364, 51.48388511757748),
  'I11f': LatLng(25.376323831360903, 51.48494350153811),

  'I03': LatLng(25.378817713816293, 51.48342119215998),
  'I06': LatLng(25.380643787796444, 51.481912360606444),
  'I08': LatLng(25.37988015721793, 51.482720527517),

  // H series
  'H08m': LatLng(25.378627213100078, 51.485784586139374),
  'H08f': LatLng(25.3767535825156, 51.48698055938411),

  'H07m': LatLng(25.380083667560896, 51.48692088481661),
  'H07f': LatLng(25.378934489421194, 51.48663916055145),

  'H10': LatLng(25.379627085925716, 51.49016028066605),
  'H12': LatLng(25.38046481732248, 51.491811717125984),

  // A / B / C / D
  'A06': LatLng(25.378124440299285, 51.49158060045566),
  'A07': LatLng(25.377296788397643, 51.49312032574497),

  'B13m': LatLng(25.377661503696263, 51.49047014057098),
  'B13f': LatLng(25.37750423808213, 51.488897080467154),

  'B03': LatLng(25.37524774172289, 51.492901227889526),

  'D05': LatLng(25.374760002402123, 51.48711292847968),
  'D06': LatLng(25.373481982344842, 51.4857422195123),
  'D04': LatLng(25.37367115319947, 51.48777028639902),

  'C11': LatLng(25.374296317071014, 51.48757258895679),
  'C07': LatLng(25.373260616357925, 51.48825006414136),
  'C05': LatLng(25.372089099584354, 51.488961932841086),

  'METRO': LatLng(25.381821556363867, 51.493005795317956),
  'male_hostel': LatLng(25.366425918064117, 51.48567172372412),
  'female_hostel': LatLng(25.37018888742163, 51.483284426567515),
};

class BusDetailsScreen extends StatefulWidget {
  final String destination;

  const BusDetailsScreen({
    super.key,
    required this.destination,
  });

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  GoogleMapController? _mapController;
  List<BusRoute> _availableRoutes = [];
  List<Bus> _availableBuses = [];
  bool _isLoading = true;
  // Store redistributed arrival times for buses on each route
  final Map<String, Map<String, int>> _redistributedTimes = {};
  // Store departure minutes (1-5) for buses when they go below 1 minute
  final Map<String, int> _departureMinutes = {};
  final Random _random = Random();
  final ScheduleService _scheduleService = ScheduleService();
  Map<String, dynamic>? _stopScheduleData = null;
  bool _isLoadingSchedule = false;
  Map<String, List<int>> _stopSchedule = {};
  BitmapDescriptor? _liveBusIcon;
  String? _focusedBusId;
  bool isLightColor(Color color) {
  return color.computeLuminance() > 0.85;
  }
  String getScheduleKeyForRoute(BusRoute route) {
    const hostelRoutes = {
      'mhostel1',
      'mhostel2',
      'mhostel3',
      'fhostela',
      'fhostelb',
      'fhostelc',
    };
    if (hostelRoutes.contains(route.id)) {
      return route.id;
    }

    final name = route.name.toLowerCase();

  if (name.contains('black')) return 'male black';
  if (name.contains('white')) return 'male white';
  if (name.contains('maroon')) return 'male maroon';
  if (name.contains('brown')) return 'male brown';

  if (name.contains('orange')) return 'female orange';
  if (name.contains('light blue')) return 'female light blue';
  if (name.contains('blue')) return 'female blue';
  if (name.contains('dark green')) return 'female dark green';
  if (name.contains('light green')) return 'female light green';
  if (name.contains('pink')) return 'female pink';
  if (name.contains('purple')) return 'female purple';
  if (name.contains('zone a')) return 'female zone a';
  if (name.contains('zone b')) return 'female zone b';
  if (name.contains('zone c')) return 'female zone c';
  if (name.contains('red')) return 'female red';
  if (name.contains('metro a')) return 'female metro a';
  if (name.contains('metro b')) return 'female metro b';
  if (name.contains('metro c')) return 'female metro c';

    return '';
  }



  final Map<String, int> routeBusCount = {
  // female
  'female light blue': 4,
  'female blue': 3,
  'female dark green': 5,
  'female light green': 3,
  'female purple': 2,
  'female pink': 3,
  'female orange': 3,
  'female zone a': 4,
  'female zone b': 5,

  // metro
  'female metro a': 2,
  'female metro b': 2,
  'female metro c': 2,

  // male
  'male black': 3,
  'male white': 2,
  'male brown': 3,
  'male maroon': 2,

  // hostel shuttles
  'mhostel1': 1,
  'mhostel2': 1,
  'mhostel3': 1,
  'fhostela': 1,
  'fhostelb': 1,
  'fhostelc': 1,
};




  @override
  void initState() {
    super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadBusData();     // loads routes + buses
    _loadSchedule();    // loads schedule
    LiveBusMarkerIcon.get().then((icon) {
      if (mounted) setState(() => _liveBusIcon = icon);
    });
  });
}

  Future<void> _loadBusData() async {
    final busService = Provider.of<BusService>(context, listen: false);
    final convexBusService = Provider.of<ConvexBusService>(context, listen: false);
    // Initialize route/stop data (kept for UI lookups)
    await busService.initializeCampusData();

    if (!mounted) return;

    // Load routes serving the destination
    final routes = busService.getRoutesToDestination(widget.destination);

    // Load live buses from Convex and filter to relevant routes
    final realBuses = convexBusService.getAllActiveBuses();
    final combinedBuses = <String, Bus>{};

    for (final bus in realBuses) {
      final isOnValidRoute = routes.any((route) => route.id == bus.routeId);
      if (!isOnValidRoute) continue;

      // Keep the bus's provided estimatedArrival if available
      combinedBuses[bus.id] = bus;
    }

    setState(() {
      _availableRoutes = routes;
      _availableBuses = combinedBuses.values.toList();
      _isLoading = false;
    });

    // Listen to Convex bus updates (ConvexBusService is a ChangeNotifier)
    convexBusService.addListener(_updateBusesFromConvex);

    // Load schedule data for the destination
    if (widget.destination != null) {
      _loadSchedule();
    }
  }

  String _getStopIdFromName(String name) {
    final busService = Provider.of<BusService>(context, listen: false);
    for (final stop in busService.getAllStops()) {
      if (stop.name.toLowerCase() == name.toLowerCase()) {
        return stop.id;
      }
    }
    return name;
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoadingSchedule = true);
    final stopId = _getStopIdFromName(widget.destination);
    final rawData = await _scheduleService.getStopSchedule(stopId);
    if (mounted && rawData != null) {
      final processed = _scheduleService.getNextBuses(rawData);
      setState(() {
        _stopScheduleData = rawData;
        _stopSchedule = processed;
        _isLoadingSchedule = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingSchedule = false);
    }
  }

  void _updateBuses() {
    if (!mounted) return;
    
    try {
      final convexBusService = Provider.of<ConvexBusService>(context, listen: false);
      final realBuses = convexBusService.getAllActiveBuses();

      final combinedBuses = <String, Bus>{};
      for (final bus in realBuses) {
        final isOnValidRoute = _availableRoutes.any((route) => route.id == bus.routeId);
        if (!isOnValidRoute) continue;
        combinedBuses[bus.id] = bus;
      }

      setState(() {
        _availableBuses = combinedBuses.values.toList();
      });
      _followFocusedBus();
    } catch (e) {
      debugPrint('Error updating buses: $e');
      // Continue with existing buses if update fails
    }
  }

  void _updateBusesFromConvex() {
    // Simple wrapper that calls the main update path
    _updateBuses();
  }

  @override
  void dispose() {
    try {
      if (mounted) {
        final convexBusService = Provider.of<ConvexBusService>(context, listen: false);
        convexBusService.removeListener(_updateBusesFromConvex);
      }
    } catch (e) {
      // Provider might not be available during dispose
      debugPrint('Error removing listener: $e');
    }
    _mapController?.dispose();
    super.dispose();
  }

  void _followFocusedBus() {
    if (_focusedBusId == null || _mapController == null) return;

    for (final bus in _availableBuses) {
      if (bus.id == _focusedBusId) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(bus.currentLocation),
        );
        BusEtaHelper.showOnMap(
          mapController: _mapController,
          markerId: 'bus_${bus.id}',
        );
        return;
      }
    }
  }

  void _clearFocusedBus() {
    final busId = _focusedBusId;
    if (busId == null) return;
    setState(() => _focusedBusId = null);
    BusEtaHelper.hideFromMap(
      mapController: _mapController,
      markerId: 'bus_$busId',
    );
  }

  LatLng _destinationStopLocation() {
    final stopId = _getStopIdFromName(widget.destination);
    return stopCoordinates[stopId] ?? const LatLng(25.3700, 51.4831);
  }

  void _focusOnBus(Bus bus) {
    setState(() => _focusedBusId = bus.id);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(bus.currentLocation, 18),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      BusEtaHelper.showOnMap(
        mapController: _mapController,
        markerId: 'bus_${bus.id}',
      );
    });
  }

  Widget? _buildFocusedBusEtaCard() {
    if (_focusedBusId == null) return null;

    Bus? bus;
    for (final candidate in _availableBuses) {
      if (candidate.id == _focusedBusId) {
        bus = candidate;
        break;
      }
    }
    if (bus == null) return null;

    final stopLocation = _destinationStopLocation();
    final eta = BusEtaHelper.compute(bus.currentLocation, stopLocation);
    final busLabel = bus.id.contains('_')
        ? 'Bus ${bus.id.split('_').last}'
        : 'Bus ${bus.id}';

    return BusEtaMapCard(
      busLabel: busLabel,
      routeName: _getRouteName(bus.routeId),
      stopName: widget.destination,
      eta: eta,
      routeColor: _getRouteColorAsColor(bus.routeId),
      onClose: _clearFocusedBus,
    );
  }

  Set<Marker> _getMarkers() {
    final markers = <Marker>{};
    final busIcon = _liveBusIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    final stopLocation = _destinationStopLocation();

    if (_liveBusIcon == null) {
      LiveBusMarkerIcon.get().then((icon) {
        if (mounted) setState(() => _liveBusIcon = icon);
      });
    }

    for (final bus in _availableBuses) {
      if (_availableRoutes.any((route) => route.id == bus.routeId)) {
        final routeName = _getRouteName(bus.routeId);
        final etaInfo = BusEtaHelper.compute(bus.currentLocation, stopLocation);

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
              stopName: widget.destination,
              eta: etaInfo,
            ),
            onTap: () => _focusOnBus(bus),
          ),
        );
      }
    }

    return markers;
  }

  double _getRouteColor(String routeId) {
    final route = _availableRoutes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: Duration.zero,
      ),
    );
    
    switch (route.color) {
      case '#FF5722':
        return BitmapDescriptor.hueOrange;
      case '#2196F3':
        return BitmapDescriptor.hueBlue;
      case '#4CAF50':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  String _getRouteName(String routeId) {
    final route = _availableRoutes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: Duration.zero,
      ),
    );
    return route.name;
  }

  Color _getRouteColorAsColor(String routeId) {
    final route = _availableRoutes.firstWhere(
      (r) => r.id == routeId,
      orElse: () => BusRoute(
        id: routeId,
        name: 'Unknown Route',
        description: '',
        color: '#666666',
        stopIds: [],
        estimatedDuration: Duration.zero,
      ),
    );

    try {
      return Color(int.parse(route.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF666666);
    }
  }

  List<Bus> _getBusesForRoute(String routeId) {
    var buses = _availableBuses.where((bus) => bus.routeId == routeId).toList();
    
    // Initialize redistributed times map for this route if needed
    if (!_redistributedTimes.containsKey(routeId)) {
      _redistributedTimes[routeId] = {};
    }
    
    // Add some randomness: occasionally shuffle bus order for variety
    if (_random.nextDouble() < 0.3 && buses.length > 1) {
      buses = List.from(buses)..shuffle(_random);
    }
    
    // Redistribute arrival times with randomness
    final totalBuses = buses.length;
    final routeTimes = _redistributedTimes[routeId]!;
    
    if (buses.isNotEmpty) {
      // Calculate base spacing with randomness
      for (int i = 0; i < buses.length; i++) {
        final bus = buses[i];
        
        // Only redistribute if bus is running (not at stop)
        final isAtStop = bus.status == BusStatus.stopped || bus.id.startsWith('at_stop_');
        
        if (!isAtStop) {
          // Use cached redistributed time or calculate new one with randomness
          if (!routeTimes.containsKey(bus.id)) {
            int baseMinutes;
            
            // Calculate base time with variation based on bus position
            if (totalBuses == 1) {
              // Single bus: 2-5 minutes with randomness
              baseMinutes = 2 + _random.nextInt(4);
            } else if (totalBuses == 2) {
              // Two buses: first 2-5 min, second 10-14 min
              baseMinutes = i == 0 
                  ? (2 + _random.nextInt(4))  // 2-5
                  : (10 + _random.nextInt(5));  // 10-14
            } else if (totalBuses == 3) {
              // Three buses: spread with randomness
              if (i == 0) {
                baseMinutes = 1 + _random.nextInt(3); // 1-3 min
              } else if (i == 1) {
                baseMinutes = 5 + _random.nextInt(4); // 5-8 min
              } else {
                baseMinutes = 12 + _random.nextInt(4); // 12-15 min
              }
            } else {
              // 4+ buses: spread evenly with randomness
              final spacing = (13.0 / (totalBuses - 1)).ceil();
              final base = 2 + (i * spacing);
              // Add variation: -1 to +2 minutes
              baseMinutes = (base + _random.nextInt(4) - 1).clamp(1, 15);
            }
            
            routeTimes[bus.id] = baseMinutes;
          } else {
            // Even cached times get slight random variation on display (within ±1 min)
            final cached = routeTimes[bus.id]!;
            // Only apply small variation, keep within bounds
            final variation = _random.nextInt(3) - 1; // -1, 0, or +1
            routeTimes[bus.id] = (cached + variation).clamp(1, 15);
          }
        }
      }
    }
    
    // Shuffle the final list occasionally for visual variety (not too often)
    if (_random.nextDouble() < 0.15 && buses.length > 1) {
      buses = List.from(buses)..shuffle(_random);
    }
    
    return buses;
  }

  // Returns: [displayText, isDeparture, isDepartingSoon]
  List<dynamic> _formatArrivalTime(DateTime? arrivalTime, Bus bus, String routeId) {
    // Check if bus is at a stop waiting to depart (stopped status or ID prefix indicates at stop)
    final isAtStop = bus.status == BusStatus.stopped || 
                     bus.id.startsWith('at_stop_');
    
    if (isAtStop) {
      // Bus is at stop waiting to depart - show "will depart in X minutes" (1-5 minutes)
      final now = DateTime.now();
      int minutes;
      if (arrivalTime != null) {
        minutes = arrivalTime.difference(now).inMinutes;
      } else {
        // Default departure time if not specified
        minutes = 3 + (bus.currentStopIndex % 3); // 3-5 mins
      }
      if (minutes < 1) minutes = 1;
      if (minutes > 5) minutes = 5;
      return ['will depart in $minutes ${minutes == 1 ? 'minute' : 'minutes'}', true, false];
    } else {
      // Bus is running to destination - use redistributed time or fallback
      int minutes;
      bool isDepartingSoon = false;
      
      // Get minutes from cached redistributed time or actual time
      if (_redistributedTimes.containsKey(routeId) && 
          _redistributedTimes[routeId]!.containsKey(bus.id)) {
        // Use cached redistributed time, but check if it's actually below 1 minute now
        minutes = _redistributedTimes[routeId]![bus.id]!;
        
        // Check actual time to see if countdown has reached below 1 minute
        if (arrivalTime != null) {
          final now = DateTime.now();
          final actualDifference = arrivalTime.difference(now);
          if (actualDifference.inMinutes < 1 && actualDifference.inSeconds > 0) {
            // Show "Departing in X minutes" when under 1 minute
            isDepartingSoon = true;
            // Use cached departure minute or generate a random one (1-5) once per bus
            if (!_departureMinutes.containsKey(bus.id)) {
              _departureMinutes[bus.id] = 1 + _random.nextInt(5); // Random 1-5
            }
            minutes = _departureMinutes[bus.id]!;
          }
        }
      } else if (arrivalTime != null) {
        final now = DateTime.now();
        final difference = arrivalTime.difference(now);
        minutes = difference.inMinutes;
        
        // If less than 1 minute, show "Departing in X minutes" (random 1-5, fixed per bus)
        if (minutes < 1 && difference.inSeconds > 0) {
          isDepartingSoon = true;
          // Use cached departure minute or generate a random one (1-5) once per bus
          if (!_departureMinutes.containsKey(bus.id)) {
            _departureMinutes[bus.id] = 1 + _random.nextInt(5); // Random 1-5
          }
          minutes = _departureMinutes[bus.id]!;
        } else if (minutes < 1) {
          minutes = 1;
        }
        if (minutes > 15) minutes = 15;
      } else {
        // Fallback to default
        minutes = 5;
      }
      
      String displayText;
      if (isDepartingSoon) {
        displayText = 'Departing in $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      } else {
        displayText = '$minutes ${minutes == 1 ? 'min' : 'mins'}';
      }
      
      return [displayText, false, isDepartingSoon];
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final stopId = _getStopIdFromName(widget.destination);

final target =
    stopCoordinates[stopId] ?? const LatLng(25.3700, 51.4831);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
        title: Text(
          'Routes to $destination',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B0000)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map section with rounded bottom, similar to reference design
                SizedBox(
                  height: 260,
                  child: Builder(
                    builder: (context) {
                      final focusedBusCard = _buildFocusedBusEtaCard();

                      return ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: Stack(
                          children: [
                            GoogleMap(
                              onMapCreated: (GoogleMapController controller) {
                                _mapController = controller;

                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                    _mapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(target, 17.5),
                                    );
                                  },
                                );
                              },
                              initialCameraPosition: CameraPosition(
                                target: target,
                                zoom: 17.5,
                              ),
                              markers: _getMarkers(),
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              mapType: MapType.satellite,
                              onTap: (_) => _clearFocusedBus(),
                            ),
                            if (focusedBusCard != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: focusedBusCard,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Cleaner top text section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Routes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_availableRoutes.length} routes serve $destination',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7B8794),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Modern cards & bus timing shadows
                Expanded(
                  child: _availableRoutes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_bus_outlined,
                                size: 64,
                                color: Color(0xFFCCCCCC),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No routes available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              Text(
                                'Try selecting a different destination',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _availableRoutes.length,
                          itemBuilder: (context, index) {
                            final route = _availableRoutes[index];
                            final buses = _getBusesForRoute(route.id);
                            final routeColor = Color(
                              int.parse(route.color.substring(1), radix: 16) +
                                  0xFF000000,
                            );
                            final isLight = isLightColor(routeColor);
                            final scheduleKey = getScheduleKeyForRoute(route);

                            final hasSchedule = scheduleKey.isNotEmpty &&
                                _stopSchedule.containsKey(scheduleKey);

                            final times =
                                hasSchedule ? _stopSchedule[scheduleKey]! : [];
                            final count = routeBusCount[scheduleKey] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLight
                                          ? const Color(0xFFF5F7FA)
                                          : routeColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(18),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.route,
                                          color: isLight
                                              ? const Color(0xFF1F2933)
                                              : Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                route.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLight
                                                      ? const Color(0xFF1F2933)
                                                      : Colors.white,
                                                ),
                                              ),
                                              if (route.description.isNotEmpty)
                                                Text(
                                                  route.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isLight
                                                        ? const Color(0xFF6B7280)
                                                        : Colors.white70,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '$count buses',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isLight
                                                  ? const Color(0xFF1F2933)
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(18),
                                      ),
                                      border: Border.fromBorderSide(
                                        BorderSide(color: Color(0xFFE4E7EB)),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (hasSchedule)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              12,
                                              12,
                                              12,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'NEXT DEPARTURES',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.8,
                                                    color: Color(0xFF9AA5B1),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: times
                                                      .take(4)
                                                      .map((t) {
                                                    return ScheduleArrivalPill(
                                                      busTimeMinutes: t,
                                                      scheduleService:
                                                          _scheduleService,
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (hasSchedule && buses.isNotEmpty)
                                          const Divider(
                                            height: 1,
                                            color: Color(0xFFE4E7EB),
                                          ),
                                        if (buses.isNotEmpty ||
                                            !hasSchedule)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              12,
                                              12,
                                              12,
                                              12,
                                            ),
                                            child: buses.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              'No buses currently running on this route',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9AA5B1),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          )
                                        : Column(
                                            children: buses.map((bus) {
                                              final isFocused =
                                                  _focusedBusId == bus.id;
                                              return Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  onTap: () => _focusOnBus(bus),
                                                  child: Container(
                                                margin: const EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isFocused
                                                      ? const Color(0xFFFFF8E7)
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: isFocused
                                                      ? Border.all(
                                                          color: const Color(
                                                            0xFF8B0000,
                                                          ),
                                                          width: 1.5,
                                                        )
                                                      : null,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      blurRadius: 14,
                                                      offset:
                                                          const Offset(0, 6),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: bus.status ==
                                                                BusStatus.running
                                                            ? Colors.green
                                                            : bus.status ==
                                                                    BusStatus
                                                                        .delayed
                                                                ? Colors.orange
                                                                : Colors.grey,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Bus ${bus.id.contains('_') ? bus.id.split('_').last : bus.id}',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                0xFF1F2933,
                                                              ),
                                                            ),
                                                          ),
                                                          if (!bus.id.startsWith(
                                                                  'mock_') &&
                                                              bus.driverName
                                                                  .isNotEmpty)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                top: 2,
                                                              ),
                                                              child: Text(
                                                                bus.driverName,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xFF7B8794,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                              top: 2,
                                                            ),
                                                            child: Text(
                                                              bus.status
                                                                  .toString()
                                                                  .split('.')
                                                                  .last
                                                                  .toUpperCase(),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                letterSpacing:
                                                                    0.4,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: bus.status ==
                                                                        BusStatus
                                                                            .running
                                                                    ? Colors
                                                                        .green
                                                                    : bus.status ==
                                                                            BusStatus
                                                                                .delayed
                                                                        ? Colors
                                                                            .orange
                                                                        : const Color(
                                                                            0xFF9AA5B1,
                                                                          ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        final stopLocation =
                                                            _destinationStopLocation();
                                                        final isLiveGps =
                                                            !bus.id.startsWith(
                                                          'mock_',
                                                        );
                                                        final liveEta = isLiveGps
                                                            ? BusEtaHelper.compute(
                                                                bus.currentLocation,
                                                                stopLocation,
                                                              )
                                                            : null;

                                                        String displayText;
                                                        Color pillBg;
                                                        Color pillText;

                                                        if (liveEta != null) {
                                                          displayText =
                                                              liveEta.etaText;
                                                          pillBg = const Color(
                                                            0xFFE6F4EA,
                                                          );
                                                          pillText = const Color(
                                                            0xFF137333,
                                                          );
                                                        } else {
                                                          final arrivalInfo =
                                                              _formatArrivalTime(
                                                            bus.estimatedArrival,
                                                            bus,
                                                            route.id,
                                                          );
                                                          displayText =
                                                              arrivalInfo[0]
                                                                  as String;
                                                          final isDeparture =
                                                              arrivalInfo[1]
                                                                  as bool;
                                                          final isDepartingSoon =
                                                              arrivalInfo[2]
                                                                  as bool;

                                                          if (isDeparture) {
                                                            pillBg = const Color(
                                                              0xFFFFE5E5,
                                                            );
                                                            pillText =
                                                                const Color(
                                                              0xFF8B0000,
                                                            );
                                                          } else if (isDepartingSoon) {
                                                            pillBg = const Color(
                                                              0xFFFFF3CD,
                                                            );
                                                            pillText =
                                                                const Color(
                                                              0xFF856404,
                                                            );
                                                          } else {
                                                            pillBg = const Color(
                                                              0xFFE3F9E5,
                                                            );
                                                            pillText =
                                                                const Color(
                                                              0xFF037F4C,
                                                            );
                                                          }
                                                        }

                                                        return Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (liveEta != null)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                  right: 10,
                                                                ),
                                                                child: Text(
                                                                  liveEta
                                                                      .distanceText,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize: 13,
                                                                    color: Color(
                                                                      0xFF5F6368,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 14,
                                                                vertical: 7,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: pillBg,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                  999,
                                                                ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black
                                                                        .withOpacity(
                                                                      0.08,
                                                                    ),
                                                                    blurRadius:
                                                                        10,
                                                                    offset:
                                                                        const Offset(
                                                                      0,
                                                                      4,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Text(
                                                                displayText,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color:
                                                                      pillText,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

              ],
            ),
    );
  }
}
