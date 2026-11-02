import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/auth_provider.dart';
import '../services/home_widgets.dart';
import '../services/review_service.dart';
import 'dashboard_tab.dart';
import 'finance_tab.dart';
import 'support_tab.dart';
import 'services_hub_tab.dart';
import 'profile_tab.dart';
import 'video_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    DashboardTab(),
    FinanceTab(),
    SupportTab(),
    ServicesHubTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Load account data on first open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final acc = context.read<AccountProvider>();
      final api = context.read<AuthProvider>().api;
      // виджет «открыть видео / баланс» — и при холодном запуске, и в работающем приложении
      HomeWidgets.listen(_openFromWidget);
      final target = await HomeWidgets.takeLaunchTarget();
      if (target != null) _openFromWidget(target);
      await acc.loadStatus();
      acc.loadHistory();
      HomeWidgets.sync(api);
      // Try to show in-app review for loyal users
      final balance = acc.status?.balance ?? 0;
      ReviewService.tryRequestReview(balancePositive: balance >= 0);
    });
  }

  void _openFromWidget(String target) {
    if (!mounted) return;
    if (target == 'video') {
      setState(() => _currentIndex = 3);
      Navigator.of(context).popUntil((r) => r.isFirst);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VideoScreen()));
    } else if (target == 'balance') {
      Navigator.of(context).popUntil((r) => r.isFirst);
      setState(() => _currentIndex = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Финансы',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent),
            label: 'Поддержка',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Услуги',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
