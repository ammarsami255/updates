import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:el_moza3/core/theme/app_theme.dart';
import 'package:el_moza3/screens/home_screen.dart';
import 'package:el_moza3/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:el_moza3/features/auth/presentation/bloc/auth_state_event.dart';
import 'package:el_moza3/features/auth/presentation/screens/splash_screen.dart';
import 'package:el_moza3/features/auth/presentation/screens/login_screen.dart';
import 'package:el_moza3/features/auth/presentation/screens/register_screen.dart';
import 'package:el_moza3/infrastructure/di/injection.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize dependency injection (instead of singletons)
  await initializeDependencies();
  
  runApp(const ElMoza3App());
}

class ElMoza3App extends StatelessWidget {
  const ElMoza3App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(),
      child: MaterialApp(
        title: 'الموزّع',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'SA'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ar', 'SA'),
        home: const AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(), // Connect to existing home screen
        },
      ),
    );
  }
}

/// Auth wrapper that handles auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return const SplashScreen();
        }
        return const HomeScreen();
      },
    );
  }
}