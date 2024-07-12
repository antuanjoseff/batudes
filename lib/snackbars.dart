import 'package:flutter/material.dart';

void snackBarConnectionRestored (context) {
  ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.thumb_up, color: Colors.white),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text("Connection restord")
                  )
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
}


void snackBarConnectionLost (context) {
  ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.white,),
            SizedBox(width: 20),                  
            Expanded(
              child: Text("Check your internet connection")
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
  );
}