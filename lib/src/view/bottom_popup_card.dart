// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';

import 'popup_window.dart';

const double MAX_CLOSE_HEIGHT = 160; //向下滑动关闭的最大高度
const double MAX_CLOSE_VELOCITY = 700.0; //向下滑动关闭的最小速度

class BottomPopupCard {
  static show(
    BuildContext context,
    Widget child,
  ) async {
    await PopupWindow.showBottom(
      context,
      _CardWidget(child),
      barrierColor: Colors.black.withOpacity(0.6),
    );
  }
}

class _CardWidget extends StatefulWidget {
  final Widget child;

  const _CardWidget(this.child, {Key? key}) : super(key: key);

  @override
  _CardWidgetState createState() {
    return _CardWidgetState();
  }
}

class _CardWidgetState extends State<_CardWidget>
    with TickerProviderStateMixin {
  //手指滑动的高度
  double moveHeight = 0;

  //是否在进行动画
  bool isAnimForward = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _BottomWindowLayout(moveHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        child: Container(
          child: Material(
            color: Color(0xFF353535),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                //弹窗顶部可以拖动区域
                GestureDetector(
                  onVerticalDragUpdate: (DragUpdateDetails details) {
                    if (isAnimForward) return; //执行动画时，直接返回
                    setState(() {
                      //拖动的时候更新布局
                      moveHeight += details.delta.dy;
                      if (moveHeight < 0) moveHeight = 0; //最小值为0
                    });
                  },
                  onVerticalDragEnd: (DragEndDetails details) => isAnimForward
                      ? {}
                      : _popIfCan(details.primaryVelocity ?? 0.0),
                  onVerticalDragCancel: () => isAnimForward ? {} : _popIfCan(),
                  child: Container(
                    color: Color(0xFF353535),
                    height: 40,
                    child: Center(
                      //上下拖动的横线
                      child: Container(
                        height: 4,
                        width: 35,
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(255, 225, 225, 1),
                          borderRadius: BorderRadius.all(Radius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 0.5,
                  color: Colors.white12,
                ),
                widget.child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  //判断是否要关闭弹窗
  _popIfCan([double velocity = 0]) {
    //滑动距离阀值，或者速度阀值
    if (moveHeight > MAX_CLOSE_HEIGHT || velocity > MAX_CLOSE_VELOCITY) {
      //防止点击弹窗以外与cancel重复执行pop
      if (ModalRoute.of(context)?.isCurrent ?? false)
        Navigator.of(context).pop();
    } else {
      //没有滑动到关闭弹窗阀值，执行归位动画。
      isAnimForward = true; //动画执行状态
      AnimationController controller = AnimationController(
          vsync: this, duration: Duration(milliseconds: 200));
      CurvedAnimation curvedAnimation =
          CurvedAnimation(parent: controller, curve: Curves.easeOut);
      Animation animation =
          Tween<double>(begin: moveHeight, end: 0).animate(curvedAnimation);
      controller.forward(); //执行动画
      controller.addListener(() {
        setState(() {
          //刷新最后一帧布局
          moveHeight = animation.value;
        });
      });
      controller.addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            //有些时候最后一帧不是0，故将最后一帧归位
            moveHeight = 0;
          });
          isAnimForward = false; //重置动画状态
          controller.dispose(); //释放动画
        }
      });
    }
  }
}

/// 底部弹窗布局
/// 主要用作约束弹窗布局，以及拖动高度变化
class _BottomWindowLayout extends SingleChildLayoutDelegate {
  _BottomWindowLayout(this.moveHeight);

  final double moveHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return new BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      minHeight: 0.0,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double height = size.height - childSize.height + moveHeight;
    return new Offset(0.0, height);
  }

  @override
  bool shouldRelayout(_BottomWindowLayout oldDelegate) {
    return moveHeight != oldDelegate.moveHeight;
  }
}
