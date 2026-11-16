import 'package:flutter/material.dart';
import 'package:routina/application/read_today.dart';
import 'package:routina/domain/result.dart';

enum _Tab {
  home('Home', Icons.home_outlined),
  calendar('Kalender', Icons.calendar_today_outlined),
  tasks('To-Do List', Icons.check_box_outlined),
  routines('Rutinitas', Icons.repeat),
  profile('Profil', Icons.person_outline);

  const _Tab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({required this.readToday, super.key});

  final ReadToday readToday;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Tab _tab = _Tab.home;
  late Result<DateTime> _today;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _today = widget.readToday();
    _lifecycle = AppLifecycleListener(onResume: _refreshToday);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _refreshToday() => setState(() => _today = widget.readToday());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tab.label)),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab.index,
          children: [
            _HomeContent(today: _today, onRetry: _refreshToday),
            for (final _ in _Tab.values.skip(1)) const _UnavailableContent(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) {
          setState(() => _tab = _Tab.values[index]);
        },
        destinations: [
          for (final tab in _Tab.values)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.today, required this.onRetry});

  final Result<DateTime> today;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        switch (today) {
          Success(:final value) => Text(
            MaterialLocalizations.of(context).formatFullDate(value),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Failure() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tanggal perangkat belum dapat ditampilkan.'),
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        },
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text('Statistik'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/statistik'),
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Statistik')),
                  body: const SafeArea(child: _UnavailableContent()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnavailableContent extends StatelessWidget {
  const _UnavailableContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [Text('Fitur halaman ini belum tersedia.')],
    );
  }
}
