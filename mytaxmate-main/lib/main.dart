import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide User; // Assuming you have your own User model

import 'package:flutter_mytaxmate/screens/finance_tracker_screen.dart';
import 'package:flutter_mytaxmate/screens/auth_screen.dart'; // Import AuthScreen
import 'package:flutter_mytaxmate/services/supabase_service.dart';
// For now, we'll focus on the auth flow to FinanceTrackerView

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await SupabaseService().initialize();
  // JobService().initializeMockJobs(); // You can uncomment this if JobService is set up
  runApp(const MyApp());
}

// Define app-wide gradients for consistent styling
class AppGradients {
  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF003A6B), Color(0xFF5293B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lightBlueGradient = LinearGradient(
    colors: [Color(0xFF5293B8), Color(0xFF89CFF1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fullBlueGradient = LinearGradient(
    colors: [
      Color(0xFF003A6B),
      Color(0xFF1B5886),
      Color(0xFF3776A1),
      Color(0xFF5293B8),
      Color(0xFF6EB1D6),
      Color(0xFF89CFF1),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyTaxMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white, // White base background
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(
            0xFF3776A1,
          ), // Updated to palette's medium blue
          primary: const Color(0xFF3776A1),
          secondary: const Color(
            0xFF34A853,
          ), // A nice green for secondary actions
          error: const Color(0xFFEA4335),
          surface: Colors.white,
          onSurface: const Color(0xFF202124),
          background: Colors.white,
          onBackground: const Color(0xFF202124),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: Colors.grey[200]!, width: 0.5),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3776A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF3776A1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3776A1), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEA4335)),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF5F6368)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF202124),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
        ),
      ),
      initialRoute: '/', // Start with the AuthWrapper
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home':
            (context) =>
                const FinanceTrackerScreen(), // Your main screen after login
        // Add other routes from your example if needed, e.g.:
        // '/setup-profile': (context) => const SetupProfileScreen(),
        // '/profile': (context) => const ProfileScreen(),
      },
      // onGenerateRoute: (settings) { ... } // Add if you have dynamic routes
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final AuthState? authState = snapshot.data;
          if (authState?.event == AuthChangeEvent.signedIn &&
              authState?.session != null) {
            // User is signed in, navigate to home (FinanceTrackerScreen)
            // You could add profile setup logic here if needed, similar to your example
            // For now, directly go to home.
            // WidgetsBinding.instance.addPostFrameCallback((_) {
            //   Navigator.of(context).pushReplacementNamed('/home');
            // });
            // return const Scaffold(body: Center(child: CircularProgressIndicator())); // Show loading while redirecting
            return const FinanceTrackerScreen(); // Directly return the home screen
          }
        }
        // User is not signed in or session is null, show AuthScreen
        return const AuthScreen();
      },
    );
  }
}
