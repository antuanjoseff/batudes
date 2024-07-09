import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:http/http.dart' as http;
import 'page.dart';
import 'dart:convert';
import 'package:background_location/background_location.dart';
import 'package:location/location.dart' as loc;

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
  late double latitude;
  late double longitude;
  double? accuracy;
  double? altitude;
  double? bearing;
  double? speed;
  double? time;

  @override
  void initState() {
    super.initState(); //comes first for initState();
    checkGps();
  }

  loc.Location location =
      loc.Location(); //explicit reference to the Location class

  Future checkGps() async {
    if (!await location.serviceEnabled()) {
      location.requestService();
    }
    gpsEnabled = await location.serviceEnabled();
    if (gpsEnabled) {
      await BackgroundLocation.setAndroidNotification(
        title: 'Background service is running',
        message: 'Background location in progress',
      );

      await BackgroundLocation.startLocationService(distanceFilter: 1);
      BackgroundLocation.getLocationUpdates((location) {
        print(location.latitude);
        print(location.longitude);
        print(location.altitude);
        print(location.accuracy);
        setState(() {
          latitude = location.latitude!;
          longitude = location.longitude!;
          accuracy = location.accuracy;
          altitude = location.altitude;
          bearing = location.bearing;
          speed = location.speed;
          time = location.time;
        });

        controller!.animateCamera(
                          CameraUpdate.newCameraPosition(
                            const CameraPosition(
                              target: LatLng(latitude, longitude),
                            ),
                          ),
                        )
                        .then(
                          (result) => debugPrint(
                              "mapController.animateCamera() returned $result"),
                        );
        );

        controller!.setGeoJsonSource('myLocation', {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": {},
              "geometry": {
                "coordinates": [longitude, latitude],
                "type": "Point"
              }
            }
          ]
        });
      });
    }
  }

  _onMapCreated(MapLibreMapController controller) async {
    this.controller = controller;

    // await gpsChecker();

    // mapController = controller;
  }

  _onStyleLoadedCallback() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Style loaded :)"),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );

    final url =
        Uri.https('sigserver4.udg.edu', '/apps/ebatuda/batuda/get/batudes');
    final fills = await http.read(url);
    await controller!
        .addSource("fills", GeojsonSourceProperties(data: jsonDecode(fills)));
    await controller!.addFillLayer(
      "fills",
      "fills",
      const FillLayerProperties(fillColor: 'red', fillOpacity: 0.5),
    );

    controller!.addSource("myLocation", GeojsonSourceProperties(data: myLoc));

    await controller!.addCircleLayer(
      "myLocation",
      "myLocation",
      CircleLayerProperties(
        circleRadius: 10,
        circleColor: Colors.blue.toHexStringRGB(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(npoints.toString())),
        body: MapLibreMap(
          // myLocationEnabled: true,

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
    {
      "type": "Feature",
      "properties": {},
      "geometry": {
        "coordinates": [2.8253603076996683, 41.98536120732385],
        "type": "Point"
      }
    }
  ]
};
