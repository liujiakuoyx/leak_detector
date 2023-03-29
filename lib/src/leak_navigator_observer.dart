// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../leak_detector.dart';

///daley check leak
///Sometimes some pages refer to delayed callback functions
///Such as WebSocket is delay close connect.
const int _defaultCheckLeakDelay = 500;

typedef ShouldAddedRoute = bool Function(Route route);

///NavigatorObserver
class LeakNavigatorObserver extends NavigatorObserver {
  final ShouldAddedRoute? shouldCheck;
  final int checkLeakDelay;

  ///[callback] if 'null',the all route can added to LeakDetector.
  ///if not 'null', returns ‘true’, then this route will be added to the LeakDetector.
  LeakNavigatorObserver(
      {this.checkLeakDelay = _defaultCheckLeakDelay, this.shouldCheck});

  @override
  void didPop(Route route, Route? previousRoute) {
    _remove(route);
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _add(route);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _remove(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) {
      _add(newRoute);
    }
    if (oldRoute != null) {
      _remove(oldRoute);
    }
  }

  ///add a object to LeakDetector
  void _add(Route route) {
    assert(() {
      if (route is ModalRoute &&
          (shouldCheck == null || shouldCheck!.call(route))) {
        route.didPush().then((_) {
          final element = _getElementByRoute(route);
          if (element != null) {
            final key = _getRouteKey(route);
            watchObjectLeak(element, key); //Element
            watchObjectLeak(element.widget, key); //Widget
            if (element is StatefulElement) {
              watchObjectLeak(element.state, key); //State
            }
          }
        });
      }

      return true;
    }());
  }

  ///check and analyze the route
  void _remove(Route route) {
    assert(() {
      final element = _getElementByRoute(route);
      if (element != null) {
        final key = _getRouteKey(route);
        if (element is StatefulElement || element is StatelessElement) {
          //start check
          LeakDetector().ensureReleaseAsync(key, delay: checkLeakDelay);
        }
      }

      return true;
    }());
  }

  ///add obj into the group
  watchObjectLeak(Object obj, String name) {
    assert(() {
      LeakDetector().addWatchObject(obj, name);
      return true;
    }());
  }

  ///Get the ‘Element’ of our custom page
  Element? _getElementByRoute(Route route) {
    Element? element;
    if (route is ModalRoute &&
        (shouldCheck == null || shouldCheck!.call(route))) {
      //RepaintBoundary
      route.subtreeContext?.visitChildElements((child) {
        //Builder
        child.visitChildElements((child) {
          if (child.widget is Semantics) {
            //Semantics
            child.visitChildElements((child) {
              //My Page
              element = child;
            });
          } else {
            element = child;
          }
        });
      });
    }
    return element;
  }

  ///generate key by [Route]
  String _getRouteKey(Route route) {
    final hasCode = route.hashCode.toString();
    String? key = route.settings.name;
    if (key == null || key.isEmpty) {
      key = route.hashCode.toString();
    } else {
      key = '$key($hasCode)';
    }
    return key;
  }
}
