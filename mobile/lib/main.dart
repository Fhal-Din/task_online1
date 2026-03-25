import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/restaurant_api.dart';
import 'config.dart';
import 'providers/auth_provider.dart';
import 'providers/restaurant_provider.dart';
import 'realtime/socket_service.dart';
import 'realtime/realtime_binder.dart';
import 'storage.dart';
import 'ui/home_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final socket = SocketService(url: AppConfig.socketUrl);
  final auth = AuthProvider(client: apiClient, storage: AppStorage());
  final restaurant = RestaurantProvider(api: RestaurantApi(apiClient), socket: socket);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: restaurant),
        Provider.value(value: socket),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().bootstrap();
      final auth = context.read<AuthProvider>();
      final socket = context.read<SocketService>();
      final restaurant = context.read<RestaurantProvider>();
      if (auth.isAuthenticated && auth.token != null) {
        socket.connect(token: auth.token!);
        restaurant.attachRealtime();
      }
      if (mounted) {
        setState(() {
          _bootstrapped = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Order',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange)),
      home: _bootstrapped
          ? const RealtimeBinder(child: HomeScaffold())
          : const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
