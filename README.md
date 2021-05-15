# leak_detector

flutter Memory leak detection tool

## Usage

#### initialize

In order to prevent the underlying library `vm service` from crashing, please call before adding the memory leak detection object:
```dart
LeakDetector().init(maxRetainingPath: 300); //maxRetainingPath default is 300
```
Enabling leak detection will reduce performance, and Full GC may drop frames on the page. 
Initialized by `assert` in the plugin, so you don't need to turn it off when build on `release` mode.

#### Detect

On your `State` class `mixin` **StateLeakMixin**, this will automatically detect whether there is a memory leak in the `State` and its corresponding `Element` objects.

```dart
import 'package:leak_detector/leak_detector.dart';

class LeakedPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return TestPageState();
  }
}

class LeakedPageState extends State<TestPage> with StateLeakMixin {
  @override
  Widget build(BuildContext context) {
    return ...;
  }
}
```

#### Get leaked information

`LeakDetector().onLeakedStream` can register your listener, and notify the object's reference chain after detecting a memory leak.
`LeakDetector().onEventStream` can monitor internal time notifications, such as `start Gc`, `end Gc`, etc.

A preview page of the reference chain is provided. You only need to add the following code. Note that the `Bulid Context` must be able to obtain the`NavigatorState`:

```dart
import 'package:leak_detector/leak_detector.dart';

//show preview page
LeakDetector().onLeakedStream.listen((LeakedInfo info) {
  //print to console
  info.retainingPath.forEach((node) => print(node));
  //show preview page
  showLeakedInfoPage(navigatorKey.currentContext, info);
});
```

Preview page display:

<img src="https://liujiakuoyx.github.io/images/leak_detector/image1.png" width = "280" align=center />
<img src="https://liujiakuoyx.github.io/images/leak_detector/image4.png" width = "280" align=center />
<img src="https://liujiakuoyx.github.io/images/leak_detector/image2.png" width = "280" align=center />

It contains the class information of the reference chain node, the referenced attribute information, the source code of the attribute declaration, and the location of the source code (line number: column number).

#### Get memory leak recording

```dart
import 'package:leak_detector/leak_detector.dart';

getLeakedRecording().then((List<LeakedInfo> infoList) {
  showLeakedInfoListPage(navigatorKey.currentContext, infoList);
});
```


<img src="https://liujiakuoyx.github.io/images/leak_detector/image3.png" width = "280" align=center />
