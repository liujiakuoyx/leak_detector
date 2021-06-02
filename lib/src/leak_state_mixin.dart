// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'leak_detector.dart';

const int _defaultCheckLeakDelay = 500;

///Used on [State], it can automatically detect whether
///[State] and its corresponding [Stateful Element] will leak memory
@Deprecated('used [LeakNavigatorObserver]')
mixin StateLeakMixin<T extends StatefulWidget> on State<T> {
  ///daley check leak
  ///Sometimes some pages refer to delayed callback functions
  ///Such as WebSocket is delay close connect.
  int get checkLeakDelayMill => _defaultCheckLeakDelay;

  ///watch Group
  String get watchGroup => hashCode.toString();

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    assert(() {
      watchObjectLeak(this); //State
      watchObjectLeak(context); //Element
      return true;
    }());
  }

  @override
  @mustCallSuper
  void dispose() {
    super.dispose();
    assert(() {
      //start check
      LeakDetector().ensureReleaseAsync(watchGroup, delay: checkLeakDelayMill);
      return true;
    }());
  }

  //add obj into the group
  watchObjectLeak(Object obj) {
    assert(() {
      LeakDetector()
          .addWatchObject(obj, watchGroup); //'hashCode' is check group key
      return true;
    }());
  }
}
