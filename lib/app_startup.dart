import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'main.dart';

class AppStartup extends StatefulWidget {
  const AppStartup({super.key, this.initialize});

  final Future<AppSession> Function()? initialize;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<AppSession> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<AppSession> _initialize() async {
    if (widget.initialize != null) return widget.initialize!();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return AppSession.load();
  }

  void _retry() {
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppSession>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) return MyApp(session: snapshot.data);
      final error = snapshot.connectionState == ConnectionState.done
          ? snapshot.error
          : null;
      return MaterialApp(
        title: 'TinkerPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: error != null
            ? _StartupError(error: error, onRetry: _retry)
            : const _StartupLoadingScreen(),
      );
    },
  );
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(AppSpacing.large),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14192B50),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/tinker_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tinker',
                      style: TextStyle(color: AppColors.navy),
                    ),
                    TextSpan(
                      text: 'Pro',
                      style: TextStyle(color: AppColors.orange),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              const Text(
                'Sports, events, and local experiences',
                textAlign: TextAlign.center,
                style: AppTypography.supporting,
              ),
              const SizedBox(height: AppSpacing.xxLarge),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              const Text(
                'Getting your courts ready...',
                style: AppTypography.supporting,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.orange,
                size: 44,
              ),
              const SizedBox(height: AppSpacing.large),
              const Text(
                'TinkerPro could not start',
                textAlign: TextAlign.center,
                style: AppTypography.pageTitle,
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: AppTypography.supporting,
              ),
              const SizedBox(height: AppSpacing.xLarge),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    ),
  );
}
