import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';

class homePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'User Location Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LocationTracker(),
    );
  }
}

class LocationTracker extends StatefulWidget {
  @override
  _LocationTrackerState createState() => _LocationTrackerState();
}

class _LocationTrackerState extends State<LocationTracker> {
  final Location _location = Location();
  late DatabaseReference _dbRef;
  late CollectionReference _firestore;
  late CollectionReference _firestore2;
  bool _trackingStarted = false;
  String _userId = "mrinal"; // todo replace the name with user vitb email
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref("users/$_userId");
    _firestore = FirebaseFirestore.instance.collection("location_history");
    _firestore2 = FirebaseFirestore.instance.collection("sos_alerts");
  }

  Future<LocationData?> _getUserLocation() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return null;
    }

    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return null;
    }

    return await _location.getLocation();
  }

  void _startTracking() async {
    LocationData? initialLocation = await _getUserLocation();
    if (initialLocation != null) {
      await _updateLocation(initialLocation);

      // Start listening for location changes
      _locationSubscription =
          _location.onLocationChanged.listen((currentLocation) {
        _updateLocation(currentLocation);
      });

      setState(() {
        _trackingStarted = true;
      });
    } else {
      _showErrorDialog("Location permission is required to track location.");
    }
  }

  void _stopTracking() {
    // Cancel the location subscription
    _locationSubscription?.cancel();
    _locationSubscription = null;

    setState(() {
      _trackingStarted = false;
    });
  }

  Future<void> _updateLocation(LocationData locationData) async {
    await _dbRef.set({
      "latitude": locationData.latitude,
      "longitude": locationData.longitude,
      "timestamp": DateTime.now().toIso8601String(),
    });
    await _firestore.doc(_userId).collection("locations").add({
      "userId": _userId,
      "latitude": locationData.latitude,
      "longitude": locationData.longitude,
      "timestamp": DateTime.now(),
    });
    await _firestore.doc(_userId).set({
      "userId": _userId,
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Cancel the location subscription if active
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _sendSOS() async {
    try {
      // Get current location
      final LocationData currentLocation = await _location.getLocation();

      // Create SOS data
      Map<String, dynamic> sosData = {
        "userId": _userId,
        "message": "Emergency! Please help.",
        "timestamp": FieldValue.serverTimestamp(),
        "latitude": currentLocation.latitude,
        "longitude": currentLocation.longitude,
      };

      // Send data to Firebase
      await FirebaseFirestore.instance
          .collection("sos_alerts")
          .doc(_userId)
          .collection("alerts")
          .add(sosData);
      await _firestore2.doc(_userId).set({
        "userId": _userId,
      }); // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SOS Alert Sent Successfully!")),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send SOS: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User app'),
      ),
      body: Center(
        child: _trackingStarted
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _sendSOS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text(
                      "Send SOS",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    "Location tracking is active.",
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _stopTracking,
                    child: Text("Stop Tracking"),
                  ),
                ],
              )
            : Column(
                children: [
                  ElevatedButton(
                    onPressed: _sendSOS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text(
                      "Send SOS",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _startTracking,
                    child: Text("Start Tracking"),
                  ),
                ],
              ),
      ),
    );
  }
}
