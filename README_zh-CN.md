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

在你的`State`类上`mixin` **StateLeakMixin**，这样将会自动检测`State`和其对应的`Element`对象是否存在内存泄漏。

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
  <img src="https://liujiakuoyx.github.io/images/leak_detector/image1.png" width="280"/>&nbsp;&nbsp;&nbsp;&nbsp;<img src="https://liujiakuoyx.github.io/images/leak_detector/image4.png" width="280"/>&nbsp;&nbsp;&nbsp;&nbsp;<img src="https://liujiakuoyx.github.io/images/leak_detector/image2.png" width="280"/> 
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
  <img src="https://liujiakuoyx.github.io/images/leak_detector/image3.png" width="300"/>
</center>
