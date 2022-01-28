// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

const int _windowPopupDuration = 200; // 默认启动动画时间
const Duration _kWindowDuration = Duration(milliseconds: _windowPopupDuration);

/// [show]可以显示一个根据目标widget摆放的弹窗，带有透明度淡出动画
/// [showBottom]可以显示一个底部弹窗，带有高度动画
class PopupWindow {
  /// 展示一个根据参考Widget相对位置的popupWindow
  static show(BuildContext target, Widget window,
      {double elevation = 20, //高度，阴影
      int? duration, //启动动画时间
      PopupWindowAlign? alignment, //相对目标widget位置
      Offset offset = Offset.zero, //偏移量，为了更灵活定位
      Function(Object? result)? onResult, //返回值,弹窗页面pop时回传参数
      bool barrierDismissible = true, //点击外部区域是否可以消失
      Color? barrierColor //window背景颜色，一般是半透明的
      }) {
    // 参考控件的Render
    final RenderBox? targetRender = target.findRenderObject() as RenderBox?;
    // overlay管理一层层的Widget，储存了所有需要绘制的Widget
    // 这里可以理解为整个屏幕绘制的Box，即当前整个屏幕
    final RenderBox? overlay =
        Overlay.of(target)?.context.findRenderObject() as RenderBox?;
    if (targetRender != null && overlay != null) {
      // 获取参考widget在overlay（屏幕）中相对位置
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          targetRender.localToGlobal(Offset.zero, ancestor: overlay),
          targetRender.localToGlobal(targetRender.size.bottomRight(Offset.zero),
              ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );

      /// 显示弹窗
      _showWindow(
        position,
        target,
        window,
        alignment: alignment,
        offset: offset,
        duration: duration,
        elevation: elevation,
        onResult: onResult,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
      );
    }
  }

  /// 显示底部Widget
  static showBottom(
    BuildContext context,
    Widget window, {
    double? windowHeight,
    Color barrierColor = Colors.black54,
    bool barrierDismissible = true,
    Function(Object? result)? onResult,
  }) async {
    Object? result = await Navigator.of(context).push(_BottomPopupWindowRoute(
        context,
        window,
        windowHeight, // 弹窗高度,某些情况下设置指定高度可以约束子布局的大小
        barrierColor,
        barrierDismissible));
    // 页面传回数据
    if (onResult != null) {
      onResult(result);
    }
  }

  /// 显示底部Widget
  static showPopupWindowLeft(
    BuildContext context,
    WidgetBuilder windowBuilder, {
    double? windowWidth,
    Color barrierColor = Colors.black54,
    bool barrierDismissible = true,
    Function(Object? result)? onResult,
  }) async {
    Object? result = await Navigator.of(context).push(_LeftPopupWindowRoute(
        context,
        windowBuilder,
        windowWidth, // 弹窗高度,某些情况下设置指定高度可以约束子布局的大小
        barrierColor,
        barrierDismissible));
    // 页面传回数据
    if (onResult != null) {
      onResult(result);
    }
  }

  /// 展示弹窗
  static _showWindow(RelativeRect position, BuildContext context, Widget window,
      {double elevation = 10,
      int? duration,
      PopupWindowAlign? alignment,
      Offset offset = Offset.zero,
      bool barrierDismissible = false,
      Function(Object? result)? onResult,
      Color? barrierColor}) async {
    // 启动弹窗
    Object? result = await Navigator.of(context).push(_PopupWindowRoute(
        position,
        window,
        elevation,
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
        duration,
        alignment,
        offset,
        barrierDismissible,
        barrierColor));
    // 返回数据
    if (onResult != null) {
      onResult(result);
    }
  }
}

/// PopupWindow的Route
class _PopupWindowRoute<T> extends PopupRoute<T> {
  final RelativeRect position;
  final PopupWindowAlign? alignment;
  final Widget child;
  final double elevation;
  final int? duration;
  final Offset offset;
  final bool _barrierDismissible;
  final Color? _barrierColor;

  @override
  final String barrierLabel;

  _PopupWindowRoute(
      this.position,
      this.child,
      this.elevation,
      this.barrierLabel,
      this.duration,
      this.alignment,
      this.offset,
      this._barrierDismissible,
      this._barrierColor);

  // 背景颜色，默认为空
  // 这里可以支持使用半透明背景
  @override
  Color? get barrierColor => _barrierColor;

  // 点击外部区域是否可以关闭
  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final CurveTween opacity =
        CurveTween(curve: const Interval(0.0, 1.0 / 3.0));
    // CustomSingleChildLayout提供一个delegate来约束child
    return CustomSingleChildLayout(
      delegate: _PopupMenuLayout(position, alignment, offset),
      // 弹窗显示动画
      child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (BuildContext context, Widget? child) {
            return Opacity(
              opacity: opacity.evaluate(animation),
              child: Material(
                // 高度，阴影效果
                elevation: elevation,
                color: Colors.transparent,
                child: child,
              ),
            );
          }),
    );
  }

  // 显示动画时长
  @override
  Duration get transitionDuration => duration == null || duration == 0
      ? _kWindowDuration
      : Duration(milliseconds: duration!);
}

class _PopupMenuLayout extends SingleChildLayoutDelegate {
  // 参考Widget的位置，一个矩形位置
  final RelativeRect position;

  // 相对参考Widget的摆放位置
  final PopupWindowAlign? align;

  // 为了更加灵活摆放，增加一个偏移量
  final Offset offset;

  _PopupMenuLayout(this.position, this.align, this.offset);

  @override
  bool shouldRelayout(_PopupMenuLayout oldDelegate) {
    return position != oldDelegate.position;
  }

  @override
  // 获取对child的盒约束
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // child的布局约束条件
    // loose() 宽松盒约束 大小限制在给定大小范围内
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  // 获取child的位置，size是layout自己的大小，childSize是child大小
  Offset getPositionForChild(Size size, Size childSize) {
    double x = 0, y = 0;
    // 计算位置，提供四个方向居中，其他位置后续加
    if (align == null) {
      //默认 在控件底部左对齐
      x = position.left;
      y = size.height - position.bottom;
    } else {
      switch (align) {
        case PopupWindowAlign.centerRight:
          //centerRight
          x = size.width - position.right;
          y = (position.top + size.height - position.bottom) / 2 -
              childSize.height / 2;
          break;
        case PopupWindowAlign.topCenter:
          //topCenter
          x = (position.left + size.width - position.right) / 2 -
              childSize.width / 2;
          y = position.top - childSize.height;
          break;
        case PopupWindowAlign.centerLeft:
          //centerLeft
          x = position.left - childSize.width;
          y = (position.top + size.height - position.bottom) / 2 -
              childSize.height / 2;
          break;
        case PopupWindowAlign.bottomCenter:
          //bottomCenter
          x = (position.left + size.width - position.right) / 2 -
              childSize.width / 2;
          y = size.height - position.bottom;
          break;
      }
    }

    /// 偏移量,以便于更灵活定位
    x += offset.dx;
    y += offset.dy;
    if (x + childSize.width > size.width) {
      x = size.width - childSize.width;
    }
    if (y + childSize.height > size.height) {
      y = size.height - childSize.height;
    }
    // child左上角相对
    return Offset(x, y);
  }
}

/// 弹窗和目标控件的位置关系
class PopupWindowAlign {
  final int type;

  const PopupWindowAlign(this.type);

  static const PopupWindowAlign centerRight = const PopupWindowAlign(0);
  static const PopupWindowAlign topCenter = const PopupWindowAlign(1);
  static const PopupWindowAlign centerLeft = const PopupWindowAlign(2);
  static const PopupWindowAlign bottomCenter = const PopupWindowAlign(3);
}

/// 底部popupWindow的Route
class _BottomPopupWindowRoute<T> extends PopupRoute<T> {
  final BuildContext context;
  final Widget window;
  final double? windowHeight;
  final Color _barrierColor;
  final bool _barrierDismissible;

  _BottomPopupWindowRoute(this.context, this.window, this.windowHeight,
      this._barrierColor, this._barrierDismissible);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Color get barrierColor => _barrierColor;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    Widget bottomWindow = new MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return ClipRect(
            child: CustomSingleChildLayout(
              delegate: _BottomPopupWindowLayout(animation.value,
                  contentHeight: windowHeight),
              child: window,
            ),
          );
        },
      ),
    );

    return bottomWindow;
  }

  @override
  String get barrierLabel =>
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
}

/// 左侧popupWindow的Route
class _LeftPopupWindowRoute<T> extends PopupRoute<T> {
  final BuildContext context;
  final WidgetBuilder windowBuilder;
  final double? windowWidth;
  final Color _barrierColor;
  final bool _barrierDismissible;

  _LeftPopupWindowRoute(this.context, this.windowBuilder, this.windowWidth,
      this._barrierColor, this._barrierDismissible);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Color get barrierColor => _barrierColor;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    Widget bottomWindow = new MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return ClipRect(
            child: CustomSingleChildLayout(
              delegate: _LeftPopupWindowLayout(animation.value,
                  contentWidth: windowWidth),
              child: windowBuilder(context),
            ),
          );
        },
      ),
    );

    return bottomWindow;
  }

  @override
  String get barrierLabel =>
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
}

abstract class _PopupWindowLayout extends SingleChildLayoutDelegate {
  final double progress;

  _PopupWindowLayout(this.progress);

  @override
  bool shouldRelayout(_PopupWindowLayout oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

/// 底部弹窗布局
class _BottomPopupWindowLayout extends _PopupWindowLayout {
  _BottomPopupWindowLayout(double progress, {this.contentHeight})
      : super(progress);

  final double? contentHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      minHeight: 0.0,
      // 当指定高度时设置指定高度，没有指定高度则对最大高度不加限制
      maxHeight: contentHeight ?? constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 计算动画过程中的高度
    double height = size.height - childSize.height * progress;
    return new Offset(0.0, height);
  }
}

/// 底部弹窗布局
class _LeftPopupWindowLayout extends _PopupWindowLayout {
  _LeftPopupWindowLayout(double progress, {this.contentWidth})
      : super(progress);

  final double? contentWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: 0,
      maxWidth: contentWidth ?? constraints.maxWidth,
      minHeight: constraints.maxHeight,
      // 当指定高度时设置指定高度，没有指定高度则对最大高度不加限制
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 计算动画过程中的宽
    double width = childSize.width * (progress - 1);
    return new Offset(width, 0.0);
  }
}
