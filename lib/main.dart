import 'package:flutter/material.dart';
import 'package:splash_screen_view/SplashScreenView.dart';
import 'package:web_socket_channel/io.dart';

import 'home-screen.dart';
import 'theme.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String url = 'wss://echo.websocket.org';

    /// Logo with Normal Text example
    Widget splashScreen = SplashScreenView(
      home: HomeSreen(
        channel: IOWebSocketChannel.connect(url),
      ),
      duration: 6000,
      imageSize: 128,
      imageSrc: 'assets/niptict-logo.png',
      text: 'កម្មវិធីបំលែងសំលេងទៅអត្ថបទ',
      textType: TextType.TyperAnimatedText,
      textStyle: TextStyle(
        fontSize: 24.0,
      ),
      backgroundColor: Colors.white,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: myTheme,
      title: 'Material App',
      home: splashScreen,
    );
  }
}
