import 'package:connectivity_plus/connectivity_plus.dart';
import 'snackbars.dart';

checkConnection(context) async{
  final connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.mobile) {
    print('The app is connected to a mobile network.');
  } else if (connectivityResult == ConnectivityResult.wifi) {
    print('The app is connected to a WiFi network.');
  } else if (connectivityResult == ConnectivityResult.ethernet) {
    print('The app is connected to an ethernet network.');
  } else if (connectivityResult == ConnectivityResult.vpn) {
    print('The app is connected to a VPN network.');
  } else if (connectivityResult == ConnectivityResult.bluetooth) {
    print('The app is connected via Bluetooth.');
  } else if (connectivityResult == ConnectivityResult.other) {
    print('The app is connected to a network that is not in the above mentioned networks.');
  } else if (connectivityResult == ConnectivityResult.none) {
    print('The app is not connected to any network.');
   snackBarConnectionLost(context);          

  }

  
}