import 'package:flutter/material.dart';

void showSnackbar (context, type, myText) {
  ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    type == 'success' ? Icons.thumb_up : Icons.warning_rounded, 
                    color: Colors.white
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(myText)
                  )
                ],
              ),
              backgroundColor: type=='success' ? Colors.green : Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
}

void snackBarConnectionRestored (context) {
  ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.thumb_up, color: Colors.white),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text("Connection restored")
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