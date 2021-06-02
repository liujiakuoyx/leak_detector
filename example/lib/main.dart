import 'package:flutter/material.dart';
import 'package:leak_detector/leak_detector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    LeakDetector().init(maxRetainingPath: 300);
    LeakDetector().onLeakedStream.listen((LeakedInfo info) {
      //print to console
      info.retainingPath.forEach((node) => print(node));
      //show preview page
      showLeakedInfoPage(navigatorKey.currentContext, info);
    });
    LeakDetector().onEventStream.listen((DetectorEvent event) {
      print(event);
      if (event.type == DetectorEventType.startAnalyze) {
        setState(() {
          _checking = true;
        });
      } else if (event.type == DetectorEventType.endAnalyze) {
        setState(() {
          _checking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      routes: {
        '/p1': (_) => LeakPage1(),
        '/p2': (_) => LeakPage2(),
        '/p3': (_) => LeakPage3(),
        '/p4': (_) => LeakPage4(),
      },
      navigatorObservers: [
        //used the LeakNavigatorObserver.
        LeakNavigatorObserver(
          shouldCheck: (route) {
            //You can customize which `route` can be detected
            return route.settings.name != null && route.settings.name != '/';
          },
        ),
      ],
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: Icon(
            Icons.adjust,
            color: _checking ? Colors.white : null,
          ),
          backgroundColor: _checking ? Colors.red : null,
          onPressed: () {},
        ),
        body: Container(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(navigatorKey.currentContext).pushNamed('/p1');
                  },
                  style: ButtonStyle(
                    side: MaterialStateProperty.resolveWith(
                      (states) => BorderSide(width: 1, color: Colors.blue),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('jump(Stateless,widget leaked)'),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(navigatorKey.currentContext).pushNamed('/p2');
                  },
                  style: ButtonStyle(
                    side: MaterialStateProperty.resolveWith(
                      (states) => BorderSide(width: 1, color: Colors.blue),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('jump(Stateful,widget leaked)'),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(navigatorKey.currentContext).pushNamed('/p3');
                  },
                  style: ButtonStyle(
                    side: MaterialStateProperty.resolveWith(
                      (states) => BorderSide(width: 1, color: Colors.blue),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('jump(Stateful,state leaked)'),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(navigatorKey.currentContext).pushNamed('/p4');
                  },
                  style: ButtonStyle(
                    side: MaterialStateProperty.resolveWith(
                      (states) => BorderSide(width: 1, color: Colors.blue),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('jump(Stateful,element leaked)'),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                TextButton(
                  onPressed: () {
                    getLeakedRecording().then((List<LeakedInfo> infoList) {
                      showLeakedInfoListPage(
                          navigatorKey.currentContext, infoList);
                    });
                  },
                  style: ButtonStyle(
                    side: MaterialStateProperty.resolveWith(
                      (states) => BorderSide(width: 1, color: Colors.blue),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text('read history'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LeakPage1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop(this);
            },
            style: ButtonStyle(
              side: MaterialStateProperty.resolveWith(
                (states) => BorderSide(width: 1, color: Colors.blue),
              ),
            ),
            child: Text('back'),
          ),
        ),
      ),
    );
  }
}

class LeakPage2 extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return LeakPageState2();
  }
}

class LeakPageState2 extends State<LeakPage2> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop(widget);
            },
            style: ButtonStyle(
              side: MaterialStateProperty.resolveWith(
                (states) => BorderSide(width: 1, color: Colors.blue),
              ),
            ),
            child: Text('back'),
          ),
        ),
      ),
    );
  }
}

class LeakPage3 extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return LeakPageState3();
  }
}

class LeakPageState3 extends State<LeakPage3> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop(this);
            },
            style: ButtonStyle(
              side: MaterialStateProperty.resolveWith(
                (states) => BorderSide(width: 1, color: Colors.blue),
              ),
            ),
            child: Text('back'),
          ),
        ),
      ),
    );
  }
}

class LeakPage4 extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return LeakPageState4();
  }
}

class LeakPageState4 extends State<LeakPage4> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop(context);
            },
            style: ButtonStyle(
              side: MaterialStateProperty.resolveWith(
                (states) => BorderSide(width: 1, color: Colors.blue),
              ),
            ),
            child: Text('back'),
          ),
        ),
      ),
    );
  }
}
