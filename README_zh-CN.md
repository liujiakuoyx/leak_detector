# leak_detector

flutter内存泄漏检测工具

## 开始使用

#### 初始化

为了避免底层库`vm_service`发生crash，请在添加内存泄漏检测对象之前调用：
```dart
//maxRetainingPath:引用链的最大长度，设置越短性能越高，但是很有可能获取不到完整的泄漏路径 默认是 300
LeakDetector().init(maxRetainingPath: 300);
```
开启泄漏检测会降低性能，Full GC可能会使页面掉帧。
插件中通过`assert`语句初始化，所以您不用特意在`release`版本中关闭该插件。

#### 检测

在`MaterialApp`增加路由的监听器`LeakNavigatorObserver`，这样将会自动检测页面的`Widget`和其对应的`Element`是否存在内存泄漏，如果页面的`Widget`是`StatefulWidget`，也会自动检查其对应的`State`对象。

```dart
import 'package:leak_detector/leak_detector.dart';

@override
Widget build(BuildContext context) {
  return MaterialApp(
    navigatorObservers: [
      //used the LeakNavigatorObserver
      LeakNavigatorObserver(
        //返回false则不会校验这个页面.
        shouldCheck: (route) {
          return route.settings.name != null && route.settings.name != '/';
        },
      ),
    ],
  );
}
```

#### 获取泄漏信息

`LeakDetector().onLeakedStream`可以注册自己的监听函数，在检测到内存泄漏之后会通知对象的引用链数据。
`LeakDetector().onEventStream`可以监听内部时间的通知，如`startGc`，`endGc`等。

提供了一个引用链的预览页面，你只需要添加以下代码即可，注意其中的`BulidContext`必须能够获取`NavigatorState`：

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

页面展示效果如下:

<center class="half">
  <img src="https://liujiakuoyx.github.io/images/leak_detector/image2-1.png" width="280"/>&nbsp;&nbsp;&nbsp;&nbsp;<img src="https://liujiakuoyx.github.io/images/leak_detector/image4.png" width="280"/>&nbsp;&nbsp;&nbsp;&nbsp;<img src="https://liujiakuoyx.github.io/images/leak_detector/image2-2.png" width="280"/> 
</center>


其中包含引用链节点的类信息、被引用属性信息、属性声明源码、源码位置（行号:列号）。

#### 内存泄漏历史记录

```dart
import 'package:leak_detector/leak_detector.dart';

getLeakedRecording().then((List<LeakedInfo> infoList) {
  showLeakedInfoListPage(navigatorKey.currentContext, infoList);
});
```


<center class="half">
  <img src="https://liujiakuoyx.github.io/images/leak_detector/image2-3.png" width="300"/>
</center>


#### *真机上无法连接vm_service问题

`vm_service` 存在 [Single Client Mode](https://github.com/dart-lang/sdk/blob/master/runtime/vm/service/service.md#single-client-mode)(单一客户端模式)。

当`DDS(Dart Development Service)`连接到`vm_service`时，`vm_service`进入单一客户端模式，之后不再接受其他的`WebSocket`连接，而是将`WebSocket`转发给`DDS`，直到`DDS`与`vm_service`断开连接，则`vm_service`才能再次开始接受`WebSocket`请求。

所以当我们连接电脑运行的时候，电脑端的`DDS`会首先连接到我们的移动端的`vm_service`的`WebSocket`服务，导致我们的`leak_detector`插件无法再次连接到`vm_service`。

有两种解决办法：

- `run`完成之后，断开与电脑端的连接，然后最好重启app。

  如果是打好的测试包安装在手机上，是不存在上面的问题的，所以这种方法适用于给测试人员使用的情况下。

- 在`flutter run`后面加上`--disable-dds`参数关闭调试端的`DDS`服务，经过测试，这样做并不会造成调试端的功能问题。

  要是使用`Android Studio`也可以像下面这样配置。

  

![image](https://liujiakuoyx.github.io/images/leak_detector/peizhi1.png)



![image](https://liujiakuoyx.github.io/images/leak_detector/peizhi2.png)