import 'package:flutter/material.dart';

/// Shared scaffold: optional [fab], consistent padding, safe areas.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.fab,
    this.fabLocation,
    this.bottomBar,
    this.extendBodyBehindAppBar = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? fab;
  final FloatingActionButtonLocation? fabLocation;
  final Widget? bottomBar;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: SafeArea(
        top: appBar == null,
        bottom: bottomBar == null,
        child: body,
      ),
      floatingActionButton: fab,
      floatingActionButtonLocation:
          fabLocation ?? FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: bottomBar,
    );
  }
}
