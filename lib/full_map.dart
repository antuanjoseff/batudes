import 'package:geolocator/geolocator.dart';
import 'package:batuda/check_connectivity.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http;
import 'page.dart';
import 'snackbars.dart';
import 'dart:convert';
import 'package:background_location/background_location.dart';
import 'package:location/location.dart' as loc;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geodart/geometries.dart';

import 'package:audioplayers/audioplayers.dart';

class FullMapPage extends ExamplePage {
  const FullMapPage({super.key})
      : super(const Icon(Icons.map), 'Full screen map');

  @override
  Widget build(BuildContext context) {
    return const FullMap();
  }
}

class FullMap extends StatefulWidget {
  const FullMap({super.key});

  @override
  State createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
  bool gpsEnabled = false;
  bool mapIsCentered = true;
  MapLibreMapController? controller;
  bool _scrollGesturesEnabled = true;
  bool trackCameroMove = true;
  int npoints = 0;
  int panTime = 0;
  var isLight = true;
  String fills = '';
  Map jsonBatudes={};
  double? latitude = 0;
  double? longitude = 0;
  double? accuracy = 0;
  double? altitude = 0;
  double? bearing = 0;
  double? speed = 0;
  double? time = 0;
  bool hasInternet = false;
  bool justIn = false;
  bool justOut = false;
  bool inDanger = false;
  bool playMode = true;
  bool _isMoving = false;
  bool justStop = false;
  bool justMoved = false;
  LatLng? currentLocation;
  MultiPolygon? geodartMultiPolygon;
  late AudioPlayer player = AudioPlayer();
  final stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState(); //comes first for initState();
    player = AudioPlayer();
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
          setState(() {
            hasInternet = false;
          });
        snackBarConnectionLost(context);          
      } else {
          setState(() {
            hasInternet = true;
          });
        snackBarConnectionRestored(context);
        // _onStyleLoadedCallback();
      }
    });

    Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        if (status == ServiceStatus.enabled) {
          showSnackbar(context, 'success', 'GPS enabled!!');
        } else {
          showSnackbar(context, 'error', 'GPS disabled!!');
        }
      }
    );

  }

  @override
  void dispose() async {
     await BackgroundLocation.stopLocationService();
     super.dispose();
  }

  loc.Location location =
      loc.Location(); //explicit reference to the Location class

  Future checkGps() async {
    if (!await location.serviceEnabled()) {
      await location.requestService();
    }

    gpsEnabled = await location.serviceEnabled();
    if (gpsEnabled){
          await BackgroundLocation.stopLocationService(); //To ensure that previously started services have been stopped, if desired
          await BackgroundLocation.startLocationService(distanceFilter: 1);
    }
    // if (gpsEnabled) {
    //   await BackgroundLocation.setAndroidNotification(
    //     title: 'Background service is running',
    //     message: 'Background location in progress',
    //   );
      
    // }
  }

  void _onMapCreated(MapLibreMapController mapController) async {
    controller = mapController;
    controller!.addListener(_onMapChanged);
    await checkConnection(context);
  }


  void _onMapChanged() {
    setState(() {
      _extractMapInfo();
    });
  }

  void _extractMapInfo() {
    final position = controller!.cameraPosition;
    _isMoving = controller!.isCameraMoving;
    if (_isMoving) {
      if (!justMoved){
        justMoved = true;
        stopwatch.start();
      }
    } else {
      justMoved = false;
      justStop = true;
      panTime = stopwatch.elapsedMilliseconds;
      stopwatch.stop();
      stopwatch.reset();
      print('............................................');
      print('doSomething() executed in $panTime');
      print('$trackCameroMove');
      if (trackCameroMove && panTime > 200) {
        mapIsCentered = false;
      }

    }
  }

  _onStyleLoadedCallback() async {
    if (!hasInternet || controller == null) {
      return;
    }
    await checkGps();
    final url =
        Uri.https('sigserver4.udg.edu', '/apps/ebatuda/batuda/get/batudes');

    fills = await http.read(url);
    
    final sources = await controller!.getSourceIds();

    if (!sources.contains('fills')){
      jsonBatudes = jsonDecode(fills);
      await controller!
          .addSource("fills", GeojsonSourceProperties(data: jsonBatudes));

      await controller!.addFillLayer(
        "fills",
        "fills",
        const FillLayerProperties(
          // fillPattern: 'stripes', fillOpacity: 1),
          fillColor: "yellow",
          fillOutlineColor: "#000000",
          
        )
      );
              
    } 
    
    await controller!.addSource("myLocation", GeojsonSourceProperties(data: myLoc));
    await controller!.addCircleLayer(
          "myLocation",
          "myLocation",
          CircleLayerProperties(
            circleRadius: 10,
            circleColor: Colors.blue.toHexStringRGB(),
          ),
        );        

    if (gpsEnabled)  {
      BackgroundLocation.getLocationUpdates((location) {
        showNewLocation(location);
      }); 
    }
   
  }

  Future<void> playAlarm() async{
    String audioPath = 'audio/alarm.mp3';
    player.setVolume(1);
    await player.play(AssetSource(audioPath));
  }

  void showNewLocation(location){
    latitude = location.latitude;
    longitude = location.longitude;
    accuracy = location.accuracy;
    altitude = location.altitude;
    bearing = location.bearing;
    speed = location.speed;
    time = location.time;        
    npoints++;

    currentLocation = LatLng(location.latitude!, location.longitude!);
    final pointJson = {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "coordinates": [location.longitude, location.latitude],
            "type": "Point"
          }
        };

    Point current = Point.fromJson(pointJson);
    if (jsonBatudes.containsKey('features')) {
      for (var i=0; i < jsonBatudes['features'].length; i++) {
        geodartMultiPolygon = MultiPolygon.fromJson(jsonBatudes['features'][i]);

        bool currentState = geodartMultiPolygon!.contains(current);

        if (currentState) {
          if (!inDanger){
            justIn = true;
            justOut = false;
          }
          if (playMode) {
            playAlarm();
          }
          continue;
        } else {
          if (inDanger) {
            justOut = true;
            justIn = false;
            playMode = true; // Reset play mode
          }
        }
        inDanger = currentState;
      }
    }


    controller!.setGeoJsonSource("myLocation", {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "coordinates": [location.longitude, location.latitude],
            "type": "Point"
          }
        }
      ]
    });

    trackCameroMove = false;
    stopwatch.start();

    if (mapIsCentered) {
      centerCamera(currentLocation);
    }
    
    setState(() {});
  }

  void centerCamera(location){
    controller!.animateCamera(
        CameraUpdate.newLatLng(location), duration: const Duration(milliseconds: 100),
      )
      .then(
        (result) {
          print('........................animate camera');
          print(stopwatch.elapsedMilliseconds);
          stopwatch.stop();
          stopwatch.reset();
          trackCameroMove = true;
          debugPrint(
            "mapController.animateCamera() returned $result");
        });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('(${npoints.toString()}) (${accuracy!.floor()}m $panTime)'), actions: [
          if (!mapIsCentered)
            IconButton(
              icon:const Icon(Icons.adjust),
              onPressed: () {
                mapIsCentered = true;
                centerCamera(currentLocation);
                setState((){});
              },
            ),
          IconButton(
            icon: playMode ? const Icon(Icons.notifications_active) : const Icon(Icons.notifications_off),
            onPressed: () {
              playMode = !playMode;
              player.stop();
              setState((){});
            },
          ),
        ],),
        body: MapLibreMap(
          // myLocationEnabled: true,
          trackCameraPosition: true,
          onMapCreated: _onMapCreated,
          scrollGesturesEnabled: _scrollGesturesEnabled,
          initialCameraPosition: const CameraPosition(
            target: LatLng(42.0, 3.0),
            zoom: 13.0,
          ),
          onStyleLoadedCallback: _onStyleLoadedCallback,
          styleString:
              // 'https://geoserveis.icgc.cat/contextmaps/icgc_mapa_base_gris_simplificat.json',
              'https://geoserveis.icgc.cat/contextmaps/icgc_orto_hibrida.json',
        ));
  }
}

var myLoc = {
  "type": "FeatureCollection",
  "features": [

  ]
};
