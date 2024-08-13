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
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:volume_controller/volume_controller.dart';

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
  bool mapCentered = true;
  bool northUp = false;
  bool fullScreen = false;
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
  double bearing = 0;
  double bearingFromGps = 0;
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
  
  final stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState(); //comes first for initState();
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
          setState(() {
            hasInternet = false;
          });
        snackBarConnectionLost(context);          
      } else {
        // TODO
        // GET LAST POSITION AND CHECK FOR DANGER ZONE
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
    _extractMapInfo();
  }

  void _extractMapInfo() {
    final position = controller!.cameraPosition;
    bearing = position!.bearing;
    
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

      if (trackCameroMove && panTime > 200) {
        mapCentered = false;
      }
    }
    setState((){});
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
    VolumeController().setVolume(1.0);
    FlutterRingtonePlayer().play(
      android: AndroidSounds.notification,
      ios: IosSounds.glass,
      looping: true, // Android only - API >= 28
      volume: 0.8, // Android only - API >= 28
      asAlarm: false, // Android only - all APIs
    );    
  }

  void locationInPolygons () {
final pointJson = {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "coordinates": [currentLocation!.longitude, currentLocation!.latitude],
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
  }

  void showNewLocation(location){
    latitude = location.latitude;
    longitude = location.longitude;
    accuracy = location.accuracy;
    altitude = location.altitude;
    bearing = location.bearing;
    bearingFromGps = location.bearing;
    bearing = bearingFromGps;
    speed = location.speed;
    time = location.time;        
    npoints++;

    currentLocation = LatLng(location.latitude!, location.longitude!);

    locationInPolygons();


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

    if (mapCentered) {
      centerCamera(currentLocation);
    }
    
    setState(() {});
  }

  void setCameraBearing(degrees){
    print('=================================CAMERA BEARING ===========$degrees');
    controller!.animateCamera(
      CameraUpdate.bearingTo(degrees), duration: const Duration(milliseconds: 100),
    );
  }

  void centerCamera(location){
    
    controller!.animateCamera(
        CameraUpdate.newLatLng(location), duration: const Duration(milliseconds: 100),
      )
      .then(
        (result) {
          stopwatch.stop();
          stopwatch.reset();
          trackCameroMove = true;
          if (!northUp) {
            setCameraBearing(bearingFromGps);
          }
        });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: !fullScreen ? AppBar(title: Text('$npoints ${accuracy!.floor()}m $bearingFromGps')) : null,
        appBar: AppBar(
          toolbarHeight: !fullScreen ? 40 : 0, 
          title: Text('$npoints ${accuracy!.floor()}m $bearingFromGps')
          ),
        body: Stack(
          children: [
            MapLibreMap(compassEnabled: false,
              // myLocationEnabled: true,
              trackCameraPosition: true,
              onMapCreated: _onMapCreated,
              onMapLongClick: (point, coordinates) {
                fullScreen = !fullScreen;
                setState((){});
              },
              scrollGesturesEnabled: _scrollGesturesEnabled,
              initialCameraPosition: const CameraPosition(
                target: LatLng(42.0, 3.0),
                zoom: 13.0,
              ),
              onStyleLoadedCallback: _onStyleLoadedCallback,
              styleString:
                  // 'https://geoserveis.icgc.cat/contextmaps/icgc_mapa_base_gris_simplificat.json',
                  'https://geoserveis.icgc.cat/contextmaps/icgc_orto_hibrida.json',
            ),
           Padding(
             padding: const EdgeInsets.all(8.0),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      RotationTransition(
                        turns: AlwaysStoppedAnimation(northUp ? 0 : (-1*bearing / 360)),
                        child: CircleAvatar(
                          backgroundColor: Color(0xffffffff), 
                          child: IconButton(
                              icon: const Icon(Icons.north, color: Colors.red),
                              onPressed: () {
                                northUp = !northUp;
                                if (!northUp){
                                  bearing = bearingFromGps;
                                } else {
                                  bearing = 0;
                                }
                                setCameraBearing(bearing);
                                // print('---------------- $northUp --------------------');
                                // setState((){});
                              },
                            ),
                        ),
                      ),
                      const SizedBox(
                        height: 5
                      ),
                      if (!mapCentered)
                        CircleAvatar(
                          backgroundColor: Color(0xffffffff), 
                          child: IconButton(
                            icon:const Icon(Icons.adjust, color: Colors.red),
                            onPressed: () {
                              mapCentered = true;
                              centerCamera(currentLocation);
                              setState((){});
                            },
                          ),
                        ),
                      
                    ],
                  ),
                  CircleAvatar(
                     backgroundColor: playMode ? Color(0xffff0000) : Color(0xffffffff),
                     child: IconButton(
                        icon: playMode ? const Icon(Icons.notifications_active, color: Colors.white,) : const Icon(Icons.notifications_off, color: Colors.grey,),
                        onPressed: () {
                          playMode = !playMode;
                          
                          setState((){});
                        },
                      ),
                   ),
                 
               ],
             ),
           ),
          ],
        ));
  }
}

var myLoc = {
  "type": "FeatureCollection",
  "features": [

  ]
};
