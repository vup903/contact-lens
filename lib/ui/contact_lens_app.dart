import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/architecture_screen.dart';
import 'screens/assistant_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/scan_screen.dart';

class ContactLensApp extends StatefulWidget {
  const ContactLensApp({super.key});

  @override
  State<ContactLensApp> createState() => _ContactLensAppState();
}

class _ContactLensAppState extends State<ContactLensApp> {
  late final ContactLensState appState;

  @override
  void initState() {
    super.initState();
    appState = ContactLensState()..load();
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Lens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2457E6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FB),
        useMaterial3: true,
      ),
      home: ContactLensShell(appState: appState),
    );
  }
}

class ContactLensShell extends StatefulWidget {
  const ContactLensShell({
    required this.appState,
    super.key,
  });

  final ContactLensState appState;

  @override
  State<ContactLensShell> createState() => _ContactLensShellState();
}

class _ContactLensShellState extends State<ContactLensShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      ContactsScreen(appState: widget.appState),
      AssistantScreen(appState: widget.appState),
      ScanScreen(appState: widget.appState),
      ArchitectureScreen(appState: widget.appState),
    ];

    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contact Lens'),
            actions: [
              IconButton(
                tooltip: 'Reset sample data',
                onPressed: widget.appState.resetToSamples,
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
          body: widget.appState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: _index, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.contacts_outlined),
                selectedIcon: Icon(Icons.contacts),
                label: 'Contacts',
              ),
              NavigationDestination(
                icon: Icon(Icons.manage_search_outlined),
                selectedIcon: Icon(Icons.manage_search),
                label: 'Assistant',
              ),
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.schema_outlined),
                selectedIcon: Icon(Icons.schema),
                label: 'Architecture',
              ),
            ],
          ),
        );
      },
    );
  }
}

