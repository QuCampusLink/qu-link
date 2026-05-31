/// BusService — campus routes and stops
///
/// Loads static QU campus route and stop reference data used for map
/// markers, destination picking, and route matching. Live bus positions
/// come from `ConvexBusService`.



import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bus_models.dart';

class BusService extends ChangeNotifier{
  static final BusService _instance = BusService._internal();
  factory BusService() => _instance;
  BusService._internal();

  final List<BusRoute> _routes = [];
  final List<BusStop> _stops = [];

  bool _initialized = false;

  /// Load campus route and stop reference data.
  Future<void> initializeCampusData() async {
    if (_initialized) return;
    _initialized = true;

    await _loadCampusStops();
    await _loadCampusRoutes();
  }

  Future<void> _loadCampusStops() async {
    _stops.addAll([
// Metro Station (Main Hub) - All genders
      BusStop(
        id: 'METRO',
        name: 'Metro Station',
        description: 'Main QU Metro Station',
        location: const LatLng(25.381821556363867, 51.493005795317956),
        routes: ['black_line', 'brown_line', 'maroon_line', 'red_line','metro_a','metro_b','metro_c','mhostel1','mhostel2','mhostel3','fhostela','fhostelb','fhostelc'],
        gender: null,
      ),
      
      // Female Classrooms Building (D06) - Female Only
      BusStop(
        id: 'D06',
        name: 'D06 Female Classrooms Building (GCR)',
        description: 'D06 - Female Classrooms Building',
        location: const LatLng(25.373481982344842, 51.4857422195123),
        routes: ['blue_route', 'light_blue_route', 'dark_green_route', 'light_green_route', 'purple_route', 'zone_a', 'metro_a'],
        gender: 'female',
      ),
      
      // Women's Activity Center (C05) - Female Only
      BusStop(
        id: 'C05',
        name: 'C05 Women\'s Activity Building',
        description: 'C05 - Women\'s Activity Building',
        location: const LatLng(25.372089099584354, 51.488961932841086),
        routes: ['blue_route', 'light_blue_route', 'dark_green_route', 'light_green_route', 'pink_route', 'zone_a'],
        gender: 'female',
      ),
        
      // Ibn Al Baitar Building (I06) - All genders
      BusStop(
        id: 'I06',
        name: 'I06 College of Pharmacy (Ibn Al-Baitar)',
        description: 'I06 - College of Pharmacy / Health Sciences',
        location: const LatLng(25.380643787796444, 51.481912360606444),
        routes: ['purple_route', 'pink_route', 'black_line', 'zone_c', 'metro_c'],
        gender: null,
      ),
      
      // Tamyuz Simulation Center (I08) - All genders
      BusStop(
        id: 'I08',
        name: 'I08 Tamayuz Simulation Center',
        description: 'I08 - Tamayuz Simulation Center',
        location: const LatLng(25.37988015721793, 51.482720527517),
        routes: ['orange_route', 'black_line', 'zone_c'],
        gender: null,
      ),
      
      // Research Complex (H10) - All genders
      BusStop(
        id: 'H10',
        name: 'H10 Research Complex',
        description: 'H10 - Research Complex',
        location: const LatLng(25.379627085925716, 51.49016028066605),
        routes: ['black_line', 'brown_line', 'white_line', 'zone_b','metro_b'],
        gender: null,
      ),
      
      // Information Technology Services (B03) - All genders
      BusStop(
        id: 'B03',
        name: 'B03 Information Technology Services',
        description: 'B03 - ITS Building',
        location: const LatLng(25.37524774172289, 51.492901227889526),
        routes: ['black_line', 'white_line', 'brown_line'],
        gender: null,
      ),
      
      // Men's Foundation Building (A06) - Male Only
      BusStop(
        id: 'A06',
        name: 'A06 Men\'s Foundation Building',
        description: 'A06 - Men\'s Foundation Building',
        location: const LatLng(25.378124440299285, 51.49158060045566),
        routes: ['black_line'],
        gender: 'male',
      ),
      
      // Sports Facilities Department (A07) - All genders
      BusStop(
        id: 'A07',
        name: 'A07 Sports Facilities and Events Department',
        description: 'A07 - Sports Facilities and Events Department',
        location: const LatLng(25.377296788397643, 51.49312032574497),
        routes: ['brown_line'],
        gender: null,
      ),

      // --- New / variant stops added (routes left blank as requested) ---

      // College of Law - Male
      BusStop(
        id: 'I09m',
        name: 'I09 College of Law (Male)',
        description: 'I09 - College of Law (Male)',
        location: const LatLng(25.376087457119596, 51.48069196590328),
        routes: ['black_line', 'white_line'],
        gender: 'male',
      ),
      // College of Law - Female
      BusStop(
        id: 'I09f',
        name: 'I09 College of Law (Female)',
        description: 'I09 - College of Law (Female)',
        location: const LatLng(25.374783619645747, 51.481530834481795),
        routes: ['zone_b'],
        gender: 'female',
      ),

      // College of Education - Male
      BusStop(
        id: 'I10m',
        name: 'I10 College of Education Building (Male)',
        description: 'I10 - College of Education Building (Male)',
        location: const LatLng(25.37658898975716, 51.4828877414271),
        routes: ['black_line', 'white_line'],
        gender: 'male',
      ),
      // College of Education - Female
      BusStop(
        id: 'I10f',
        name: 'I10 College of Education Building (Female)',
        description: 'I10 - College of Education Building (Female)',
        location: const LatLng(25.37560672476257, 51.48242239454162),
        routes: ['zone_b'],
        gender: 'female',
      ),

      // Student Affairs - Male
      BusStop(
        id: 'I11m',
        name: 'I11 Student Affairs Building (Male)',
        description: 'I11 - Student Affairs Building (Male)',
        location: const LatLng(25.377979388163364, 51.48388511757748),
        routes: ['black_line', 'white_line'],
        gender: 'male',
      ),
      // Student Affairs - Female
      BusStop(
        id: 'I11f',
        name: 'I11 Student Affairs Building (Female)',
        description: 'I11 - Student Affairs Building (Female)',
        location: const LatLng(25.376323831360903, 51.48494350153811),
        routes: ['zone_b', 'red_line'],
        gender: 'female',
      ),

      // College of Nursing - All genders
      BusStop(
        id: 'I03',
        name: 'I03 College of Nursing',
        description: 'I03 - College of Nursing',
        location: const LatLng(25.378817713816293, 51.48342119215998),
        routes: ['zone_c', 'red_line'],
        gender: null,
      ),

      // College of Business and Economics - Male
      BusStop(
        id: 'H08m',
        name: 'H08 College of Business and Economics (Male)',
        description: 'H08 - College of Business and Economics (Male)',
        location: const LatLng(25.378627213100078, 51.485784586139374),
        routes: ['white_line', 'maroon_line'],
        gender: 'male',
      ),
      // College of Business and Economics - Female
      BusStop(
        id: 'H08f',
        name: 'H08 College of Business and Economics (Female)',
        description: 'H08 - College of Business and Economics (Female)',
        location: const LatLng(25.3767535825156, 51.48698055938411),
        routes: ['zone_b'],
        gender: 'female',
      ),

      // College of Engineering - Male
      BusStop(
        id: 'H07m',
        name: 'H07 College Of Engineering (Male)',
        description: 'H07 - College Of Engineering (Male)',
        location: const LatLng(25.380083667560896, 51.48692088481661),
        routes: ['black_line', 'white_line', 'maroon_line'],
        gender: 'male',
      ),
      // College of Engineering - Female
      BusStop(
        id: 'H07f',
        name: 'H07 College Of Engineering (Female)',
        description: 'H07 - College Of Engineering (Female)',
        location: const LatLng(25.378934489421194, 51.48663916055145),
        routes: ['zone_b'],
        gender: 'female',
      ),

      // College Of Medicine - All genders
      BusStop(
        id: 'H12',
        name: 'H12 College Of Medicine',
        description: 'H12 - College Of Medicine',
        location: const LatLng(25.38046481732248, 51.491811717125984),
        routes: ['zone_c', 'black_line'],
        gender: null,
      ),

      // Library - Male
      BusStop(
        id: 'B13m',
        name: 'B13 Library (Male)',
        description: 'B13 - Library (Male)',
        location: const LatLng(25.377661503696263, 51.49047014057098),
        routes: ['black_line', 'white_line', 'brown_line'],
        gender: 'male',
      ),
// Library - Female
      BusStop(
        id: 'B13f',
        name: 'B13 Library (Female)',
        description: 'B13 - Library (Female)',
        location: const LatLng(25.37750423808213, 51.488897080467154),
        routes: ['red_line'],
        gender: 'female',
      ),

      // Women's Foundation (D05) - Female Only
      BusStop(
        id: 'D05',
        name: 'D05 Women\'s Foundation',
        description: 'D05 - Women\'s Foundation',
        location: const LatLng(25.374760002402123, 51.48711292847968),
        routes: ['zone_a'],
        gender: 'female',
      ),

      // Women's Food Court (D04) - Female Only
      BusStop(
        id: 'D04',
        name: 'D04 Women\'s Food Court',
        description: 'D04 - Women\'s Food Court',
        location: const LatLng(25.37367115319947, 51.48777028639902),
        routes: ['zone_a', 'red_line'],
        gender: 'female',
      ),

      // College of Sharia & Islamic Studies (C11) - Female Only
      BusStop(
        id: 'C11',
        name: 'C11 College of Sharia & Islamic Studies (Bldn A)',
        description: 'C11 - College of Sharia & Islamic Studies (Building A)',
        location: const LatLng(25.374296317071014, 51.48757258895679),
        routes: ['zone_a'],
        gender: 'female',
      ),

      // College of Sharia & Islamic Studies (C07) - Female Only
      BusStop(
        id: 'C07',
        name: 'C07 College of Sharia & Islamic Studies (Bldn B)',
        description: 'C07 - College of Sharia & Islamic Studies (Building B)',
        location: const LatLng(25.373260616357925, 51.48825006414136),
        routes: ['zone_a','dark_green_route'],
        gender: 'female',
      ),

      // Male Hostel - Male Only
      BusStop(
        id: 'male_hostel',
        name: 'Male Hostel',
        description: 'Male student housing — mhostel1, mhostel2, mhostel3',
        location: const LatLng(25.366425918064117, 51.48567172372412),
        routes: ['mhostel1', 'mhostel2', 'mhostel3'],
        gender: 'male',
      ),

      // Female Hostel - Female Only
      BusStop(
        id: 'female_hostel',
        name: 'Female Hostel',
        description: 'Female student housing — fhostela, fhostelb, fhostelc',
        location: const LatLng(25.37018888742163, 51.483284426567515),
        routes: ['fhostela', 'fhostelb', 'fhostelc'],
        gender: 'female',
      ),
    ]);
  }

  Future<void> _loadCampusRoutes() async {
    _routes.addAll([
      // OFFICIAL QU BUS ROUTES - 7 Horizontal Routes
      
      // Dark Blue Route (المسار الأزرق الغامق)
      BusRoute(
        id: 'dark_blue_route',
        name: 'Dark Blue Route',
        description: 'Female Classrooms → Women\'s Activity → Library → Business',
        color: '#1976D2',
        stopIds: ['D06', 'C05', 'H08f', 'I06'],
        estimatedDuration: const Duration(minutes: 12),
      ),
      
      // Light Blue Route (المسار الأزرق الفاتح)
      BusRoute(
        id: 'light_blue_route',
        name: 'Light Blue Route',
        description: 'Female Classrooms → Women\'s Activity → Engineering',
        color: '#42A5F5',
        stopIds: ['D06', 'C05', 'H07f'],
        estimatedDuration: const Duration(minutes: 10),
      ),
      
      // Dark Green Route (المسار الأخضر الغامق)
      BusRoute(
        id: 'dark_green_route',
        name: 'Dark Green Route',
        description: 'Female Classrooms → Women\'s Activity → Education',
        color: '#388E3C',
        stopIds: ['D06', 'C05', 'I10f', "C07"],
        estimatedDuration: const Duration(minutes: 8),
      ),
      
      // Light Green Route (المسار الأخضر الفاتح)
      BusRoute(
        id: 'light_green_route',
        name: 'Light Green Route',
        description: 'Female Classrooms → Women\'s Activity → Law',
        color: '#66BB6A',
        stopIds: ['D06', 'C05', 'I09f'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      
      // Purple Route (المسار البنفسجي)
      BusRoute(
        id: 'purple_route',
        name: 'Purple Route',
        description: 'Female Classrooms → Al Razi → Ibn Al Baitar',
        color: '#7B1FA2',
        stopIds: ['D06', 'H12', 'I06'],
        estimatedDuration: const Duration(minutes: 10),
      ),
      
      // Pink Route (المسار الوردي)
      BusRoute(
        id: 'pink_route',
        name: 'Pink Route',
        description: 'Women\'s Activity → Al Razi → Ibn Al Baitar',
        color: '#C2185B',
        stopIds: ['C05', 'H12', 'I06'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      
      // Orange Route (المسار البرتقالي)
      BusRoute(
        id: 'orange_route',
        name: 'Orange Route',
        description: 'Tamyuz Simulation Center → Engineering → Law',
        color: '#F57C00',
        stopIds: ['I08','H07f','I09f'],
        estimatedDuration: const Duration(minutes: 10),
      ),
      
      // OFFICIAL QU METRO LINES - 4 Metro Lines
      
      // Black Line (المسار الأسود) - Main Loop
      BusRoute(
        id: 'black_line',
        name: 'Black Line (Main Loop)',
        description: 'Complete campus tour - 25 minutes',
        color: '#212121',
        stopIds: [
          'METRO', 'I06', 'I08', 'I09m', 'I10m',
          'I11m', 'H08m', 'H07m', 'H10',
          'B13m', 'B03', 'A06', 'H12'],
        estimatedDuration: const Duration(minutes: 25),
      ),
      
      // White Line (المسار الأبيض) - Inner Loop
      BusRoute(
        id: 'white_line',
        name: 'White Line (Inner Loop)',
        description: 'Inner campus loop - 18 minutes',
        color: '#FAFAFA',
        stopIds: [
          'I09m', 'I10m', 'I11m', 'H08m',
          'H07m', 'B13m', 'B03'
        ],
        estimatedDuration: const Duration(minutes: 18),
      ),
      
      // Brown Line (المسار البني) - Research & Sports
      BusRoute(
        id: 'brown_line',
        name: 'Brown Line (Research & Sports)',
        description: 'Research complex and sports facilities - 15 minutes',
        color: '#5D4037',
        stopIds: ['METRO', 'H10', 'B13m', 'B03', 'A07'],
        estimatedDuration: const Duration(minutes: 15),
      ),
      
      // Maroon Line (المسار العنابي) - Express
      BusRoute(
        id: 'maroon_line',
        name: 'Maroon Line',
        description: 'Quick express route - 8 minutes',
        color: '#8D6E63',
        stopIds: ['METRO', 'H08m', 'H07m'],
        estimatedDuration: const Duration(minutes: 8),
      ),

      // 🔴 Red Line (A-B-C Connector)
      BusRoute(
      id: 'red_line',
     name: 'Red Line',
     description: 'Zone A → B → C connector',
     color: '#D32F2F',
  stopIds: [
    'D04', // Women’s Food Court
    'B13f', // Library
    'METRO',
    'I03', // Nursing
    'I11f', // Student Affairs
  ],
  estimatedDuration: const Duration(minutes: 12),
),

      // 🅰️ Zone A Loop
BusRoute(
  id: 'zone_a',
  name: 'Zone A',
  description: 'Women’s zone loop',
  color: '#757575', // grey
  stopIds: [
    'D05', 'D06', 'D04',
    'C05', 'C07', 'C11',
  ],
  estimatedDuration: const Duration(minutes: 10),
),

// 🅱️ Zone B Loop
BusRoute(
  id: 'zone_b',
  name: 'Zone B',
  description: 'Academic zone loop',
  color: '#616161',
  stopIds: [
    'H08f', 'I10f', 'I09f',
    'I11f', 'H07f', 'H10',
  ],
  estimatedDuration: const Duration(minutes: 12),
),

// 🅲 Zone C Loop
BusRoute(
  id: 'zone_c',
  name: 'Zone C',
  description: 'Health & simulation loop',
  color: '#424242',
  stopIds: [
    'I06', 'I08', 'I03',
    'H12',
  ],
  estimatedDuration: const Duration(minutes: 10),
),

// 🟢 Metro Zone A Loop
BusRoute(
  id: 'metro_a',
  name: 'Metro A',
  description: 'Metro ↔ Zone A (D06)',
  color: '#00897B',
  stopIds: ['METRO', 'D06'],
  estimatedDuration: const Duration(minutes: 5),
),

// 🔵 Metro Zone B Loop
BusRoute(
  id: 'metro_b',
  name: 'Metro B',
  description: 'Metro ↔ Zone B (H10)',
  color: '#00796B',
  stopIds: ['METRO', 'H10'],
  estimatedDuration: const Duration(minutes: 5),
),

// 🟣 Metro Zone C Loop
BusRoute(
  id: 'metro_c',
  name: 'Metro C',
  description: 'Metro ↔ Zone C (I06)',
  color: '#00695C',
  stopIds: ['METRO', 'I06'],
  estimatedDuration: const Duration(minutes: 5),
),

      // Male Hostel shuttles
      BusRoute(
        id: 'mhostel1',
        name: 'Male Hostel Bus 1',
        description: 'Male Hostel ↔ Metro',
        color: '#1565C0',
        stopIds: ['male_hostel', 'METRO'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      BusRoute(
        id: 'mhostel2',
        name: 'Male Hostel Bus 2',
        description: 'Male Hostel ↔ Metro',
        color: '#1976D2',
        stopIds: ['male_hostel', 'METRO'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      BusRoute(
        id: 'mhostel3',
        name: 'Male Hostel Bus 3',
        description: 'Male Hostel ↔ Metro',
        color: '#1E88E5',
        stopIds: ['male_hostel', 'METRO'],
        estimatedDuration: const Duration(minutes: 8),
      ),

      // Female Hostel shuttles
      BusRoute(
        id: 'fhostela',
        name: 'Female Hostel Bus A',
        description: 'Female Hostel ↔ Metro',
        color: '#AD1457',
        stopIds: ['female_hostel', 'METRO'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      BusRoute(
        id: 'fhostelb',
        name: 'Female Hostel Bus B',
        description: 'Female Hostel ↔ Metro',
        color: '#C2185B',
        stopIds: ['female_hostel', 'METRO'],
        estimatedDuration: const Duration(minutes: 8),
      ),
      BusRoute(
        id: 'fhostelc',
        name: 'Female Hostel Bus C',
        description: 'Female Hostel ↔ Metro',
        color: '#D81B60',
        stopIds: ['female_hostel', 'METRO'],
        estimatedDuration: const Duration(minutes: 8),
      ),

    ]);
  }

  /// Get all bus routes
  List<BusRoute> getAllRoutes() {
    return List.from(_routes);
  }

  /// Get all bus stops
  List<BusStop> getAllStops() {
    return List.from(_stops);
  }

  /// Get routes that serve a specific destination
  List<BusRoute> getRoutesToDestination(String destinationName) {
    // Find the stop that matches the destination name
    final destinationStop = _stops.firstWhere(
      (stop) => stop.name.toLowerCase() == destinationName.toLowerCase(),
      orElse: () => BusStop(
        id: 'unknown',
        name: destinationName,
        description: '',
        location: const LatLng(0, 0),
        routes: [],
      ),
    );
    
    if (destinationStop.id == 'unknown') {
      return [];
    }
    
    return _routes.where((route) => 
        route.stopIds.contains(destinationStop.id)).toList();
  }

  /// Dispose resources
  @override
  void dispose() {
    // Nothing special to dispose
    super.dispose();
  }
}

