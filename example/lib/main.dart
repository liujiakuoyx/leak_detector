import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:leak_detector/leak_detector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    //must init the tools
    LeakDetector().init(maxRetainingPath: 300);
    LeakDetector().onLeakedStream.listen((LeakedInfo info) {
      showLeakedInfoPage(_navigatorKey.currentContext, info);
    });
    LeakDetector().onEventStream.listen((DetectorEvent event) {
      print(event);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlatButton(
                onPressed: () {
                  Navigator.of(_navigatorKey.currentContext).push(MaterialPageRoute(builder: (_) => TestLeakPage()));
                },
                color: Colors.blue,
                child: Text(
                  'jump',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
              FlatButton(
                onPressed: () {
                  getLeakedRecording().then((List<LeakedInfo> list) {
                    showLeakedInfoListPage(_navigatorKey.currentContext, list);
                  });
                },
                color: Colors.blue,
                child: Text(
                  'read history',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TestLeakPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return TestLeakPageState();
  }
}

class TestLeakPageState extends State with StateLeakMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('leaked page'),
      ),
      body: Center(
        child: FlatButton(
          onPressed: () {
            //the 'context' is leaked
            Navigator.of(context).pop(context);
          },
          color: Colors.blue,
          child: Text(
            'pop',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
