import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'widgets/stock_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(StockAlertApp(api: ApiService()));
}

class StockAlertApp extends StatelessWidget {
  const StockAlertApp({super.key, required this.api});

  final ApiService api;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'StockAlert',
    theme: buildStockTheme(),
    home: DashboardScreen(api: api),
  );
}
