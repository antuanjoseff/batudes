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
  MapLibreMapController? controller;
  int npoints = 0;
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
  MultiPolygon? geodartMultiPolygon;
  late AudioPlayer player = AudioPlayer();


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
    await checkConnection(context);
    
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

    final newLoc = LatLng(location.latitude!, location.longitude!);
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
        bool dangerZone = geodartMultiPolygon!.contains(current);
        print('..............................');
        print('DANGER ZONE $dangerZone');
        print(geodartMultiPolygon);
        print(current);
        print('..............................');
        if (dangerZone) {
          playAlarm();
          continue;
        }
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

    controller!.animateCamera(
        CameraUpdate.newLatLng(newLoc)
      )
      .then(
        (result) => debugPrint(
            "mapController.animateCamera() returned $result"),
      );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('${npoints.toString()} captured points'), actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () {
              player.stop();
            },
          ),
        ],),
        body: MapLibreMap(
          // myLocationEnabled: true,
          trackCameraPosition: true,
          onMapCreated: _onMapCreated,
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
