import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ ADD THIS
import 'package:ggclassroom/l10n/app_localizations.dart';
import 'routes/app_router.dart';
import 'services/mongodb_service.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('vi'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();
  
  // Initialize MongoDB connection (skip on web)
  try {
    await MongoDBService.connect();
  } catch (e) {
    // On web, this is expected - MongoDB direct connection not supported
    if (MongoDBService.isWebPlatform) {
      print('Info: MongoDB direct connection not available on web platform');
    } else {
      print('Warning: MongoDB connection failed: $e');
    }
    // Continue anyway - connection will be retried when needed
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'E-Learning',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(), // ✅ ADD THIS LINE
      ),
    );
  }
}