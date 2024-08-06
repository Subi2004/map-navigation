import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:geocoding/geocoding.dart';

class SampleNavigationApp extends StatefulWidget {
  const SampleNavigationApp({super.key});

  @override
  State<SampleNavigationApp> createState() => _SampleNavigationAppState();
}

class _SampleNavigationAppState extends State<SampleNavigationApp> {
  String? _platformVersion;
  String? _instruction;
  double? _distanceRemaining, _durationRemaining;
  MapBoxNavigationViewController? _controller;
  bool _routeBuilt = false;
  bool _isNavigating = false;
  late MapBoxOptions _navigationOption;

  final TextEditingController _startPlaceController = TextEditingController();
  final TextEditingController _endPlaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _startPlaceController.dispose();
    _endPlaceController.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    if (!mounted) return;

    _navigationOption = MapBoxNavigation.instance.getDefaultOptions();
    _navigationOption.simulateRoute = true;
    _navigationOption.language = "en";
    MapBoxNavigation.instance.registerRouteEventListener(_onEmbeddedRouteEvent);

    String? platformVersion;
    try {
      platformVersion = await MapBoxNavigation.instance.getPlatformVersion();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _startNavigation() async {
    try {
      // Convert place names to coordinates
      List<Location> startLocations = await locationFromAddress(_startPlaceController.text);
      List<Location> endLocations = await locationFromAddress(_endPlaceController.text);

      if (startLocations.isEmpty || endLocations.isEmpty) {
        _showError("Unable to find location for one or both addresses.");
        return;
      }

      double startLat = startLocations.first.latitude;
      double startLng = startLocations.first.longitude;
      double endLat = endLocations.first.latitude;
      double endLng = endLocations.first.longitude;

      var wayPoints = <WayPoint>[
        WayPoint(
            name: "Start",
            latitude: startLat,
            longitude: startLng,
            isSilent: false),
        WayPoint(
            name: "End",
            latitude: endLat,
            longitude: endLng,
            isSilent: false),
      ];

      MapBoxOptions options = MapBoxOptions.from(_navigationOption)
        ..simulateRoute = true
        ..voiceInstructionsEnabled = true
        ..bannerInstructionsEnabled = true
        ..units = VoiceUnits.metric
        ..language = "en";

      await MapBoxNavigation.instance.startNavigation(
          wayPoints: wayPoints, options: options);
    } catch (e) {
      _showError("Error starting navigation: $e");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Navigation App'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Text('Running on: $_platformVersion\n'),
                      Container(
                        color: Colors.grey,
                        width: double.infinity,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: (Text(
                            "Enter Places",
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          )),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _startPlaceController,
                              decoration: const InputDecoration(
                                labelText: 'Start Place',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _endPlaceController,
                              decoration: const InputDecoration(
                                labelText: 'End Place',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _isNavigating ? null : _startNavigation,
                              child: const Text('Start Navigation'),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: Colors.grey,
                        width: double.infinity,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: (Text(
                            "Instructions",
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          )),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          _instruction == null ? "No Instructions" : _instruction!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0, right: 20, top: 20, bottom: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Text("Duration Remaining: "),
                                Text(_durationRemaining != null
                                    ? "${(_durationRemaining! / 60).toStringAsFixed(0)} minutes"
                                    : "---")
                              ],
                            ),
                            Row(
                              children: <Widget>[
                                const Text("Distance Remaining: "),
                                Text(_distanceRemaining != null
                                    ? "${(_distanceRemaining! * 0.000621371).toStringAsFixed(1)} miles"
                                    : "---")
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider()
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 300,
                child: Container(
                  color: Colors.grey,
                  child: MapBoxNavigationView(
                    options: _navigationOption,
                    onRouteEvent: _onEmbeddedRouteEvent,
                    onCreated: (MapBoxNavigationViewController controller) async {
                      _controller = controller;
                      controller.initialize();
                    },
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onEmbeddedRouteEvent(e) async {
    _distanceRemaining = await MapBoxNavigation.instance.getDistanceRemaining();
    _durationRemaining = await MapBoxNavigation.instance.getDurationRemaining();

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        if (progressEvent.currentStepInstruction != null) {
          _instruction = progressEvent.currentStepInstruction;
        }
        break;
      case MapBoxEvent.route_building:
      case MapBoxEvent.route_built:
        setState(() {
          _routeBuilt = true;
        });
        break;
      case MapBoxEvent.route_build_failed:
        setState(() {
          _routeBuilt = false;
        });
        break;
      case MapBoxEvent.navigation_running:
        setState(() {
          _isNavigating = true;
        });
        break;
      case MapBoxEvent.on_arrival:
        await Future.delayed(const Duration(seconds: 3));
        await _controller?.finishNavigation();
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        setState(() {
          _routeBuilt = false;
          _isNavigating = false;
        });
        break;
      default:
        break;
    }
    setState(() {});
  }
}