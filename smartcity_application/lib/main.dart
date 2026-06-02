import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/category_provider.dart';
import 'providers/locale_provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize storage
  await StorageService.init();
  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ComplaintProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = LocaleProvider();
            provider.loadLocale();
            return provider;
          },
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'JanHelp',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            navigatorKey: NotificationService.navigatorKey,
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('gu'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return _KeyboardInsetSmoother(
                child: child ?? const SizedBox.shrink(),
              );
            },
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}

class _KeyboardInsetSmoother extends StatelessWidget {
  const _KeyboardInsetSmoother({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null || mediaQuery.disableAnimations) {
      return child;
    }

    final targetBottomInset = mediaQuery.viewInsets.bottom;
    final isKeyboardOpening = targetBottomInset > 0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetBottomInset),
      duration: Duration(milliseconds: isKeyboardOpening ? 360 : 260),
      curve: isKeyboardOpening
          ? Curves.fastEaseInToSlowEaseOut
          : Curves.easeOutCubic,
      child: RepaintBoundary(child: child),
      builder: (context, bottomInset, child) {
        return MediaQuery(
          data: mediaQuery.copyWith(
            viewInsets: EdgeInsets.fromLTRB(
              mediaQuery.viewInsets.left,
              mediaQuery.viewInsets.top,
              mediaQuery.viewInsets.right,
              bottomInset,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
