import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/core/constants/levels.dart';
import 'package:educonnect/core/constants/subjects.dart';
import 'package:educonnect/core/di/injection.dart';
import 'package:educonnect/core/network/api_client.dart';
import 'package:educonnect/core/router/app_router.dart';
import 'package:educonnect/core/theme/app_theme.dart';
import 'package:educonnect/features/auth/presentation/bloc/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  // Pre-load reference data from the backend so dropdowns are ready.
  // Non-blocking — if the API is unreachable the lists stay empty until
  // individual pages retry.
  final api = getIt<ApiClient>();
  await Future.wait([
    Levels.load(api),
    Subjects.load(api),
  ]);

  runApp(const EduConnectApp());
}

class EduConnectApp extends StatefulWidget {
  const EduConnectApp({super.key});

  @override
  State<EduConnectApp> createState() => _EduConnectAppState();
}

class _EduConnectAppState extends State<EduConnectApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>()..add(AuthCheckRequested());
    _router = createRouter(_authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: _authBloc),
          ],
          child: MaterialApp.router(
            title: 'EduConnect',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            routerConfig: _router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
            locale: const Locale('fr'),
          ),
        );
      },
    );
  }
}
