import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text widget',
      home: Scaffold(
        body: Center(
          child: Container(
            child: Text(
              'Hello Wen Mo Bo',
              style: TextStyle(
                  fontSize: 40
              ),
            ),
            alignment: Alignment.center,
            width: 500,
            height: 400,
            // color: Colors.purple,
            padding: const EdgeInsets.all(10.0),
            margin: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.lightBlue, Colors.greenAccent, Colors.orange]),
              border: Border.all(width: 2.0, color: Colors.red)
            ),
          ),
        ),
      ),
    );
  }
}