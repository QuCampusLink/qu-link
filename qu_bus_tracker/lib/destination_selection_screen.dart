/// Destination selection screen
///
/// Provides UI for choosing an origin and destination on the QU campus.
/// The screen offers search/autocomplete, categorized campus locations,
/// and optional map-based pickers. When a destination is selected the
/// result is returned via `Navigator.pop` so callers can compute routes
/// or filter buses.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'convex_bus_service.dart';
import 'bus_service.dart';
import 'bus_models.dart';
import 'dart:math' as math;

class DestinationSelectionScreen extends StatefulWidget {
  final String gender;

  const DestinationSelectionScreen({super.key, required this.gender});

  @override
  State<DestinationSelectionScreen> createState() => _DestinationSelectionScreenState();
}

class _DestinationSelectionScreenState extends State<DestinationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredLocations = [];
  String _selectedCategory = 'All';

  String? _selectedOrigin;
  String? _selectedDestination;
  bool _isSelectingOrigin = true; // Toggle between selecting origin and destination
  bool _isLoadingRoutes = false; // Track if routes are being loaded
  
  // Official QU campus locations organized by category
  static const Map<String, List<Map<String, String>>> _campusLocations = {
    'Bus Hubs': [
      {'name': 'Metro Station', 'description': 'Main QU Metro Station - Black, Brown, Maroon Lines'},
      {'name': 'D06 Female Classrooms Building (GCR)', 'description': 'D06 - Main hub for Blue, Light Blue, Dark Green, Light Green, Purple Routes'},
      {'name': 'C05 Women\'s Activity Building', 'description': 'C05 - Blue, Light Blue, Dark Green, Light Green, Pink Routes'},
    ],
    'Academic Buildings': [
      {'name': 'B13 Library (Male)', 'description': 'B13 - Library (Male)'},
      {'name': 'B13 Library (Female)', 'description': 'B13 - Library (Female)'},
      {'name': 'H07 College Of Engineering (Male)', 'description': 'H07 - College Of Engineering (Male)'},
      {'name': 'H07 College Of Engineering (Female)', 'description': 'H07 - College Of Engineering (Female)'},
      {'name': 'H08 College of Business and Economics (Male)', 'description': 'H08 - College of Business and Economics (Male)'},
      {'name': 'H08 College of Business and Economics (Female)', 'description': 'H08 - College of Business and Economics (Female)'},
      {'name': 'I10 College of Education Building (Male)', 'description': 'I10 - College of Education Building (Male)'},
      {'name': 'I10 College of Education Building (Female)', 'description': 'I10 - College of Education Building (Female)'},
      {'name': 'I09 College of Law (Male)', 'description': 'I09 - College of Law (Male)'},
      {'name': 'I09 College of Law (Female)', 'description': 'I09 - College of Law (Female)'},
      {'name': 'H10 Research Complex', 'description': 'H10 - Research Complex'},
    ],
    'Health Sciences': [
      {'name': 'H12 College Of Medicine', 'description': 'H12 - College Of Medicine'},
      {'name': 'I06 College of Pharmacy (Ibn Al-Baitar)', 'description': 'I06 - College of Pharmacy / Health Sciences'},
      {'name': 'I08 Tamayuz Simulation Center', 'description': 'I08 - Tamayuz Simulation Center'},
      {'name': 'I03 College of Nursing', 'description': 'I03 - College of Nursing'},
    ],
    'Administrative & Services': [
      {'name': 'I11 Student Affairs Building (Male)', 'description': 'I11 - Student Affairs Building (Male)'},
      {'name': 'I11 Student Affairs Building (Female)', 'description': 'I11 - Student Affairs Building (Female)'},
      {'name': 'B03 Information Technology Services', 'description': 'B03 - ITS Building'},
      {'name': 'A06 Men\'s Foundation Building', 'description': 'A06 - Men\'s Foundation Building'},
    ],
    'Sports & Recreation': [
      {'name': 'A07 Sports Facilities and Events Department', 'description': 'A07 - Sports Facilities and Events Department'},
    ],
    'Residence': [
      {'name': 'Male Hostel', 'description': 'Male student housing — mhostel1, mhostel2, mhostel3'},
      {'name': 'Female Hostel', 'description': 'Female student housing — fhostela, fhostelb, fhostelc'},
    ],
    'Women Only': [
      {'name': 'D05 Women\'s Foundation', 'description': 'D05 - Women\'s Foundation'},
      {'name': 'D04 Women\'s Food Court', 'description': 'D04 - Women\'s Food Court'},
      {'name': 'C11 College of Sharia & Islamic Studies (Bldn A)', 'description': 'C11 - College of Sharia & Islamic Studies (Building A)'},
      {'name': 'C07 College of Sharia & Islamic Studies (Bldn B)', 'description': 'C07 - College of Sharia & Islamic Studies (Building B)'},
    ],
  };

  List<String> get _allLocations {
    final busService = BusService();
    final allStops = busService.getAllStops();
    
    // Build a map of stop name to gender
    final stopGenderMap = <String, String?>{};
    for (var stop in allStops) {
      stopGenderMap[stop.name] = stop.gender;
    }
    
    return _campusLocations.values
        .expand((category) => category.map((location) => location['name']!))
        .where((name) {
          final gender = stopGenderMap[name];
          if (gender == null) return true;
          return gender == widget.gender;
        })
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _filteredLocations = _allLocations;
    // Initialize BusService immediately when screen loads
    _initializeBusService();
  }

  Future<void> _initializeBusService() async {
    final busService = BusService();
    if (busService.getAllStops().isEmpty) {
      setState(() {
        _isLoadingRoutes = true;
      });
      await busService.initializeCampusData();
      debugPrint('BusService initialized! Stops: ${busService.getAllStops().length}');
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        });
      }
    } else {
      debugPrint('BusService already initialized with ${busService.getAllStops().length} stops');
    }
  }

  void _filterLocations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = _getLocationsForCategory(_selectedCategory);
      } else {
        _filteredLocations = _getLocationsForCategory(_selectedCategory)
            .where((location) =>
                location.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  List<String> _getLocationsForCategory(String category) {
    if (category == 'All') {
      return _allLocations;
    }
    return _campusLocations[category]?.map((location) => location['name']!).toList() ?? [];
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filteredLocations = _getLocationsForCategory(category);
      if (_searchController.text.isNotEmpty) {
        _filterLocations(_searchController.text);
      }
    });
  }

  String? _getLocationDescription(String locationName) {
    for (List<Map<String, String>> category in _campusLocations.values) {
      for (Map<String, String> location in category) {
        if (location['name'] == locationName) {
          return location['description'];
        }
      }
    }
    return null;
  }

  void _onLocationSelected(String location) async {
    setState(() {
      if (_isSelectingOrigin) {
        _selectedOrigin = location;
        _isSelectingOrigin = false; // Switch to destination selection
        _searchController.clear();
        _filteredLocations = _getLocationsForCategory(_selectedCategory);
      } else {
        _selectedDestination = location;
      }
    });
    
    // Ensure BusService is initialized when both locations are selected
    if (_selectedOrigin != null && _selectedDestination != null) {
      await _ensureBusServiceInitialized();
    }
  }
  
  Future<void> _ensureBusServiceInitialized() async {
    final busService = BusService();
    if (busService.getAllStops().isEmpty) {
      setState(() {
        _isLoadingRoutes = true;
      });
      await busService.initializeCampusData();
      if (mounted) {
        setState(() {
          _isLoadingRoutes = false;
        }); // Force rebuild to show routes
      }
    }
  }

  // Get routes that serve both origin and destination
  List<String> _getConnectingRoutes() {
    if (_selectedOrigin == null || _selectedDestination == null) {
      return [];
    }

    final busService = BusService();
    var allStops = busService.getAllStops();
    
    // If stops are empty, trigger initialization and return empty for now
    // The _ensureBusServiceInitialized will handle the async initialization
    if (allStops.isEmpty) {
      debugPrint('WARNING: BusService has no stops. Should be initialized by _ensureBusServiceInitialized.');
      return [];
    }
    
    // Find origin and destination stops with flexible matching
    debugPrint('Looking for origin: "${_selectedOrigin}"');
    debugPrint('Looking for destination: "${_selectedDestination}"');
    debugPrint('Available stops: ${allStops.map((s) => s.name).toList()}');
    
    // Helper to find stop with flexible matching
    BusStop? findStop(String locationName) {
      final normalized = locationName.toLowerCase().trim();
      try {
        return allStops.firstWhere(
          (stop) {
            final stopName = stop.name.toLowerCase().trim();
            return stopName == normalized || 
                   stopName.contains(normalized) || 
                   normalized.contains(stopName);
          },
          orElse: () => BusStop(
            id: 'unknown',
            name: locationName,
            description: '',
            location: const LatLng(0, 0),
            routes: [],
          ),
        );
      } catch (e) {
        return null;
      }
    }
    
    final originStop = findStop(_selectedOrigin!);
    final destinationStop = findStop(_selectedDestination!);
    
    if (originStop == null) {
      debugPrint('ORIGIN NOT FOUND: "${_selectedOrigin}"');
      debugPrint('Tried to match against: ${allStops.map((s) => s.name).toList()}');
      return [];
    }
    
    if (destinationStop == null) {
      debugPrint('DESTINATION NOT FOUND: "${_selectedDestination}"');
      debugPrint('Tried to match against: ${allStops.map((s) => s.name).toList()}');
      return [];
    }
    
    debugPrint('✓ Origin stop found: ${originStop.name}, routes: ${originStop.routes}');
    debugPrint('✓ Destination stop found: ${destinationStop.name}, routes: ${destinationStop.routes}');
    
    // Find routes that serve both locations
    final originRoutes = originStop.routes.toSet();
    final destinationRoutes = destinationStop.routes.toSet();
    final commonRoutes = originRoutes.intersection(destinationRoutes);
    
    debugPrint('Common routes: $commonRoutes');
    
    return commonRoutes.toList();
  }

  // No pseudo 'at_stop' buses: rely solely on live Convex buses for ETAs.

  // Get buses with route information and ETAs
  List<Map<String, dynamic>> _getAvailableBusesWithRoutes() {
    if (_selectedOrigin == null || _selectedDestination == null) {
      return [];
    }

    final connectingRoutes = _getConnectingRoutes();
    if (connectingRoutes.isEmpty) {
      debugPrint('No connecting routes found!');
      return [];
    }

    final convexBusService = Provider.of<ConvexBusService>(context, listen: false);
    final busService = BusService();
    final allBuses = convexBusService.getAllActiveBuses();
    final allRoutes = busService.getAllRoutes();
    
    debugPrint('Connecting routes: $connectingRoutes');
    debugPrint('Total active buses from Convex: ${allBuses.length}');
    
    // Filter buses that are on connecting routes
    final connectingBuses = allBuses.where((bus) {
      final isConnecting = connectingRoutes.contains(bus.routeId);
      debugPrint('Bus ${bus.id} on route ${bus.routeId}: ${isConnecting ? "YES" : "NO"}');
      return isConnecting && bus.status == BusStatus.running;
    }).toList();

    debugPrint('Connecting buses found: ${connectingBuses.length}');
    
  // Use only live connecting buses from Convex (no pseudo 'at_stop' buses)
  final allConnectingBuses = connectingBuses;
    
    debugPrint('Total buses (incoming + at stop): ${allConnectingBuses.length}');
    
    // Get route information and calculate ETAs
    final busesWithInfo = allConnectingBuses.map((bus) {
      final route = allRoutes.firstWhere(
        (r) => r.id == bus.routeId,
        orElse: () => BusRoute(
          id: bus.routeId,
          name: bus.routeId,
          description: '',
          color: '#000000',
          stopIds: [],
          estimatedDuration: const Duration(minutes: 0),
        ),
      );
      
      // Calculate ETA based on bus's estimatedArrival or fallback calculation
      final now = DateTime.now();
      int minutesUntilArrival;
      bool isAtStop = false; // Track if bus is at origin stop
      
      // Check if bus is at the origin stop (same location or very close)
      final originStop = busService.getAllStops().firstWhere(
        (stop) => stop.name.toLowerCase().trim() == _selectedOrigin!.toLowerCase().trim(),
        orElse: () => BusStop(
          id: 'unknown',
          name: _selectedOrigin!,
          description: '',
          location: const LatLng(0, 0),
          routes: [],
        ),
      );
      
  // Check if this bus is at the origin by location proximity
  final distanceToOrigin = _calculateDistance(bus.currentLocation, originStop.location);
  final isAtOriginStop = (distanceToOrigin < 50); // 50 meters threshold
      
      if (isAtOriginStop) {
        isAtStop = true;
        // For buses at stop, show "will depart in 3-5 minutes"
        if (bus.estimatedArrival != null) {
          minutesUntilArrival = bus.estimatedArrival!.difference(now).inMinutes;
          // Clamp to 3-5 minutes range for departure time
          if (minutesUntilArrival < 3) minutesUntilArrival = 3;
          if (minutesUntilArrival > 5) minutesUntilArrival = 5;
        } else {
          // Random departure time between 3-5 minutes
          minutesUntilArrival = 3 + (bus.currentStopIndex % 3); // 3-5 mins
        }
      } else {
        // Normal incoming buses - ETA range 1-10 minutes
        if (bus.estimatedArrival != null) {
          minutesUntilArrival = bus.estimatedArrival!.difference(now).inMinutes;
        } else {
          // Fallback: estimate based on last update (assume 1-10 min ETA)
          final timeSinceUpdate = now.difference(bus.lastUpdated).inMinutes;
          // Generate ETA between 1-10 minutes based on bus index and time since update
          minutesUntilArrival = 1 + ((bus.currentStopIndex + timeSinceUpdate) % 10);
        }
      }
      
      // Ensure positive ETA with correct ranges
      if (minutesUntilArrival <= 0) {
        minutesUntilArrival = isAtStop 
            ? (3 + (bus.currentStopIndex % 3)) // 3-5 mins for buses at stop
            : (1 + (bus.currentStopIndex % 10)); // 1-10 mins for incoming buses
      }
      
      // Ensure ETA stays in correct range
      if (isAtStop) {
        // Buses at stop: 3-5 minutes until departure
        minutesUntilArrival = minutesUntilArrival.clamp(3, 5);
      } else {
        // Buses on the way: 1-10 minutes
        minutesUntilArrival = minutesUntilArrival.clamp(1, 10);
      }
      
      return {
        'bus': bus,
        'route': route,
        'etaMinutes': minutesUntilArrival > 0 ? minutesUntilArrival : 1,
        'isAtStop': isAtStop, // Mark buses at the origin stop
      };
    }).toList();

    // Sort by ETA (earliest first)
    busesWithInfo.sort((a, b) => (a['etaMinutes'] as int).compareTo(b['etaMinutes'] as int));
    
    return busesWithInfo;
  }

  List<Bus> _getAvailableBuses() {
    final busesWithInfo = _getAvailableBusesWithRoutes();
    return busesWithInfo.map((item) => item['bus'] as Bus).toList();
  }

  // Get routes summary for display - shows routes even if no buses
  List<Map<String, dynamic>> _getRoutesSummary() {
    final connectingRoutes = _getConnectingRoutes();
    if (connectingRoutes.isEmpty) {
      return [];
    }

    final busService = BusService();
    final allRoutes = busService.getAllRoutes();
    final busesWithInfo = _getAvailableBusesWithRoutes();
    final Map<String, List<Map<String, dynamic>>> routesMap = {};
    
    // Group buses by route
    for (var item in busesWithInfo) {
      final routeId = (item['route'] as BusRoute).id;
      if (!routesMap.containsKey(routeId)) {
        routesMap[routeId] = [];
      }
      routesMap[routeId]!.add(item);
    }
    
    // Create summary for ALL connecting routes (even if no buses)
    final routesSummary = connectingRoutes.map((routeId) {
      final route = allRoutes.firstWhere(
        (r) => r.id == routeId,
        orElse: () => BusRoute(
          id: routeId,
          name: routeId.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
          description: '',
          color: '#000000',
          stopIds: [],
          estimatedDuration: const Duration(minutes: 0),
        ),
      );
      
      final routeBuses = routesMap[routeId] ?? [];
      final buses = routeBuses.map((item) => item['bus'] as Bus).toList();
      final earliestETA = routeBuses.isNotEmpty 
          ? routeBuses.map((item) => item['etaMinutes'] as int).reduce((a, b) => a < b ? a : b)
          : null;
      
      return {
        'route': route,
        'buses': buses,
        'earliestETA': earliestETA,
      };
    }).toList();
    
    // Sort by ETA if available, otherwise keep original order
    routesSummary.sort((a, b) {
      if (a['earliestETA'] == null && b['earliestETA'] == null) return 0;
      if (a['earliestETA'] == null) return 1;
      if (b['earliestETA'] == null) return -1;
      return (a['earliestETA'] as int).compareTo(b['earliestETA'] as int);
    });
    
    return routesSummary;
  }

  void _clearSelections() {
    setState(() {
      _selectedOrigin = null;
      _selectedDestination = null;
      _isSelectingOrigin = true;
      _searchController.clear();
      _filteredLocations = _getLocationsForCategory(_selectedCategory);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure BusService is initialized if both locations are selected
    final bothSelected = _selectedOrigin != null && _selectedDestination != null;
    
    if (bothSelected && !_isLoadingRoutes) {
      // Immediately check and initialize if needed
      final busService = BusService();
      if (busService.getAllStops().isEmpty) {
        // Trigger async initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureBusServiceInitialized();
        });
      }
    }
    
    final availableBuses = _getAvailableBuses();
    final routesSummary = _getRoutesSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Route',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF8B0000),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Origin and Destination Selection Cards at the top
          Container(
            color: const Color(0xFF8B0000),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Origin Selection Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _isSelectingOrigin = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _isSelectingOrigin 
                                    ? const Color(0xFF8B0000).withOpacity(0.1)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.my_location,
                                color: _isSelectingOrigin 
                                    ? const Color(0xFF8B0000)
                                    : Colors.grey[600],
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Where are you?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedOrigin ?? 'Select your current location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedOrigin != null
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedOrigin != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                color: Colors.grey[600],
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _selectedOrigin = null;
                                    _isSelectingOrigin = true;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Destination Selection Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (_selectedOrigin != null) {
                          setState(() {
                            _isSelectingOrigin = false;
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select your origin first'),
                              backgroundColor: Color(0xFF8B0000),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: !_isSelectingOrigin && _selectedOrigin != null
                                    ? const Color(0xFF8B0000).withOpacity(0.1)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: !_isSelectingOrigin && _selectedOrigin != null
                                    ? const Color(0xFF8B0000)
                                    : Colors.grey[600],
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Where are you going?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedDestination ?? 'Select your destination',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDestination != null
                                          ? const Color(0xFF2C2C2C)
                                          : Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedDestination != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                color: Colors.grey[600],
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _selectedDestination = null;
                                    _isSelectingOrigin = false;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Show Available Routes and Buses if both are selected
          if (bothSelected)
            Builder(
              builder: (context) {
                final totalBuses = availableBuses.length;
                final totalRoutes = routesSummary.length;
                final connectingRoutes = _getConnectingRoutes();
                
                debugPrint('=== BUILD BANNER ===');
                debugPrint('Routes summary: $totalRoutes');
                debugPrint('Connecting routes: $connectingRoutes');
                debugPrint('Available buses: $totalBuses');
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: totalRoutes > 0 ? Colors.green[50] : Colors.orange[50],
                  child: Row(
                    children: [
                      Icon(
                        totalRoutes > 0 ? Icons.check_circle : Icons.warning,
                        color: totalRoutes > 0 ? Colors.green[700] : Colors.orange[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          totalRoutes > 0
                              ? '$totalRoutes route${totalRoutes != 1 ? 's' : ''} • $totalBuses bus${totalBuses != 1 ? 'es' : ''} available'
                              : 'No routes available between these locations',
                          style: TextStyle(
                            color: totalRoutes > 0 ? Colors.green[700] : Colors.orange[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearSelections,
                        child: const Text(
                          'Change',
                          style: TextStyle(color: Color(0xFF8B0000)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Search Bar (only show when selecting location)
          if (!bothSelected)
          Container(
            color: const Color(0xFF8B0000),
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterLocations,
                  decoration: InputDecoration(
                    hintText: _isSelectingOrigin 
                        ? 'Search for your current location...'
                        : 'Search for your destination...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF8B0000)),
                  border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Category Filter (only show when selecting location)
          if (!bothSelected)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All'),
                const SizedBox(width: 8),
                ..._campusLocations.keys.map((category) => [
                      _buildCategoryChip(category),
                      const SizedBox(width: 8),
                    ]).expand((element) => element),
              ],
            ),
          ),

          // Content: Either Locations List or Available Buses
          Expanded(
            child: bothSelected
                ? (_isLoadingRoutes 
                    ? const Center(child: CircularProgressIndicator())
                    : _buildAvailableBusesList(availableBuses))
                : _buildLocationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    if (_filteredLocations.isEmpty) {
      return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Color(0xFFCCCCCC),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No locations found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF666666),
                          ),
                        ),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
      );
    }

    return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredLocations.length,
                    itemBuilder: (context, index) {
                      final location = _filteredLocations[index];
                      final description = _getLocationDescription(location);
        final isSelected = _isSelectingOrigin
            ? _selectedOrigin == location
            : _selectedDestination == location;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B0000).withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFF8B0000), width: 2)
                : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
              onTap: () => _onLocationSelected(location),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8B0000).withOpacity(0.2)
                            : const Color(0xFF8B0000).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                      child: Icon(
                        _isSelectingOrigin ? Icons.my_location : Icons.location_on,
                        color: const Color(0xFF8B0000),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          location,
                            style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                              color: isSelected 
                                  ? const Color(0xFF8B0000)
                                  : const Color(0xFF2C2C2C),
                                          ),
                                        ),
                                        if (description != null)
                                          Text(
                                            description,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF8B0000),
                        size: 24,
                      )
                    else
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
                      );
                    },
    );
  }

  Widget _buildAvailableBusesList(List<Bus> buses) {
    final routesSummary = _getRoutesSummary();
    
    if (routesSummary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No routes available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No routes connect these locations',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: routesSummary.length,
      itemBuilder: (context, index) {
        final routeInfo = routesSummary[index];
        final route = routeInfo['route'] as BusRoute;
        final routeBuses = routeInfo['buses'] as List<Bus>;
        final earliestETA = routeInfo['earliestETA'] as int?;
        
        // Get route color - handle hex colors properly
        Color routeColor;
        try {
          final hexColor = route.color.startsWith('#') ? route.color.substring(1) : route.color;
          routeColor = Color(int.parse(hexColor, radix: 16) + 0xFF000000);
        } catch (e) {
          debugPrint('Error parsing route color ${route.color}: $e');
          routeColor = const Color(0xFF8B0000); // Default to QU red
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Route Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: routeColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: routeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: routeColor,
                            ),
                          ),
                          if (route.description.isNotEmpty)
                            Text(
                              route.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (earliestETA != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: earliestETA <= 5 ? Colors.green[100] : Colors.orange[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$earliestETA min',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: earliestETA <= 5 ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'No buses',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Buses in this route
              if (routeBuses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No buses currently running on this route',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...routeBuses.asMap().entries.map((entry) {
                final bus = entry.value;
                final busesWithInfo = _getAvailableBusesWithRoutes();
                final busInfo = busesWithInfo.firstWhere(
                  (item) => (item['bus'] as Bus).id == bus.id,
                  orElse: () => <String, Object>{
                    'bus': bus,
                    'route': BusRoute(
                      id: bus.routeId,
                      name: bus.routeId,
                      description: '',
                      color: '#000000',
                      stopIds: [],
                      estimatedDuration: const Duration(minutes: 0),
                    ),
                    'etaMinutes': 5,
                    'isAtStop': false,
                  },
                );
                final etaMinutes = busInfo['etaMinutes'] as int;
                final isAtStop = busInfo['isAtStop'] as bool? ?? false;
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context, {
                          'origin': _selectedOrigin,
                          'destination': _selectedDestination,
                          'busId': bus.id,
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Color(0xFF8B0000),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bus ${bus.id.replaceAll(RegExp(r'[_-]'), ' ').toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C2C2C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isAtStop
                                        ? 'Currently at ${_selectedOrigin ?? "stop"} • Ready to depart'
                                        : 'Driver: ${bus.driverName.isNotEmpty ? bus.driverName : "Unknown"} • Bus: ${bus.id}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isAtStop 
                                    ? Colors.orange[50] 
                                    : (etaMinutes <= 5 ? Colors.green[50] : Colors.blue[50]),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                isAtStop 
                                    ? 'Will depart in $etaMinutes min' 
                                    : '$etaMinutes min',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isAtStop
                                      ? Colors.orange[700]
                                      : (etaMinutes <= 5 ? Colors.green[700] : Colors.blue[700]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Color(0xFF8B0000),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onCategorySelected(category),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFF8B0000) 
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF666666),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Calculate distance between two points (Haversine formula)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final double a = math.pow(math.sin(deltaLatRad / 2), 2).toDouble() + 
                     math.cos(lat1Rad) * math.cos(lat2Rad) * 
                     math.pow(math.sin(deltaLngRad / 2), 2).toDouble();
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}