import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // providerパッケージをインポート
import 'package:kakeibo_smartphone_app/screens/home_page.dart';
import 'package:kakeibo_smartphone_app/screens/calendar_page.dart';
import 'package:kakeibo_smartphone_app/screens/analytics_page.dart';
import 'package:kakeibo_smartphone_app/viewmodels/transaction_viewmodel.dart'; // TransactionViewModelをインポート

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialAppをChangeNotifierProviderでラップする
    return ChangeNotifierProvider(
      create: (context) => TransactionViewModel(), // ここでTransactionViewModelを提供
      child: MaterialApp(
        title: '家計簿アプリ',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const HomePage(),
    const CalendarPage(),
    const AnalyticsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: '入力',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'カレンダー',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '分析',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}
