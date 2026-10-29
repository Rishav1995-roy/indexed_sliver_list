import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'feed_screen.dart';
import 'settings.dart';
import 'settings_screen.dart';

/// Root of the example app (also pumped by the demo-GIF generator).
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key, this.initialTab = 0, this.brightness});
  final int initialTab;
  final Brightness? brightness;

  @override
  State<ExampleApp> createState() => ExampleAppState();
}

class ExampleAppState extends State<ExampleApp> {
  final DemoSettings settings = DemoSettings();
  final GlobalKey<FeedScreenState> feedKey = GlobalKey<FeedScreenState>();
  final GlobalKey<ChatScreenState> chatKey = GlobalKey<ChatScreenState>();
  late int tab = widget.initialTab;

  @override
  void dispose() {
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, _) => MaterialApp(
        title: 'indexed_sliver_list',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: settings.seed,
            brightness: widget.brightness ?? Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: tab,
              children: <Widget>[
                FeedScreen(key: feedKey, settings: settings),
                ChatScreen(key: chatKey),
                SettingsScreen(settings: settings),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (int i) => setState(() => tab = i),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                  icon: Icon(Icons.view_agenda_outlined), label: 'Feed'),
              NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Customize'),
            ],
          ),
        ),
      ),
    );
  }
}
