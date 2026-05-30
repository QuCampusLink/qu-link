/// App entrypoint
///
/// Initializes Flutter, configures top-level providers, and sets up the
/// `MaterialApp` with routes and theme.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'gender_selection_screen.dart';
import 'bus_service.dart';
import 'convex_bus_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QUBusTrackerApp());
}

class QUBusTrackerApp extends StatelessWidget {
  const QUBusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BusService()),
        ChangeNotifierProvider(create: (_) => ConvexBusService()),
      ],
      child: MaterialApp(
        title: 'QU Bus Tracker',
        theme: ThemeData(
          primarySwatch: MaterialColor(
            0xFF8B0000,
            const <int, Color>{
              50: Color(0xFFFDE7E7),
              100: Color(0xFFFACACA),
              200: Color(0xFFF6AAAA),
              300: Color(0xFFF18989),
              400: Color(0xFFED7070),
              500: Color(0xFF8B0000),
              600: Color(0xFF7D0000),
              700: Color(0xFF6B0000),
              800: Color(0xFF5A0000),
              900: Color(0xFF3A0000),
            },
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B0000),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF8B0000),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: const GenderSelectionScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
