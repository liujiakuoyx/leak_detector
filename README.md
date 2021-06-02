[中文文档](README_zh-CN.md)

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

Add `LeakNavigatorObserver` to `navigatorObservers` in `MaterialApp`, it will automatically detect whether there is a memory leak in the page's `Widget` and its corresponding `Element` object. If page's Widget is a `StatefulWidget`, it will also be automatically checked Its corresponding `State`.

```dart
import 'package:leak_detector/leak_detector.dart';

@override
Widget build(BuildContext context) {
  return MaterialApp(
    navigatorObservers: [
      //used the LeakNavigatorObserver
      LeakNavigatorObserver(
        shouldCheck: (route) {
          return route.settings.name != null && route.settings.name != '/';
        },
      ),
    ],
  );
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

<img src="https://liujiakuoyx.github.io/images/leak_detector/image2-1.png" width = "280" align=center />

<img src="https://liujiakuoyx.github.io/images/leak_detector/image4.png" width = "280" align=center />

<img src="https://liujiakuoyx.github.io/images/leak_detector/image2-2.png" width = "280" align=center />

It contains the class information of the reference chain node, the referenced attribute information, the source code of the attribute declaration, and the location of the source code (line number: column number).

#### Get memory leak recording

```dart
import 'package:leak_detector/leak_detector.dart';

getLeakedRecording().then((List<LeakedInfo> infoList) {
  showLeakedInfoListPage(navigatorKey.currentContext, infoList);
});
```


<img src="https://liujiakuoyx.github.io/images/leak_detector/image2-3.png" width = "280" align=center />

#### *Cannot connect to `vm_service` on real mobile devices

The VM service allows for an extended feature set via the Dart Development Service (DDS) that forward all core VM service RPCs described in this document to the true VM service.

So when we connect to the computer to run, the `DDS` on the computer will first connect to the `vm_service` on our mobile end, causing our `leak_detector` plugin to fail to connect to the `vm_service` again.

There are two solutions:

- After the `run` is complete, disconnect from the computer, and then it is best to restart the app.

  If the completed test package is installed on the mobile phone, the above problem does not exist, so this method is suitable for use by testers.

- Add the `--disable-dds` parameter after `flutter run` to turn off the `DDS`. After testing, this will not cause any impact on debugging

  It can be configured as follows in `Android Studio`.

  

![image](https://liujiakuoyx.github.io/images/leak_detector/peizhi1.png)



![image](https://liujiakuoyx.github.io/images/leak_detector/peizhi2.png)