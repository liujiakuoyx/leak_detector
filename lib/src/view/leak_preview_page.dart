// Copyright (c) 2021, Jiakuo Liu. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import '../leak_data_store.dart';
import '../leak_data.dart';
import 'bottom_popup_card.dart';
import 'popup_window.dart';

const _colorList = [Color(0xff1e7ce4), Color(0xffe4881e)];

void showLeakedInfoPage(BuildContext context, LeakedInfo leakInfo) {
  BottomPopupCard.show(
    context,
    LeakPreviewPage(leakInfoList: [leakInfo]),
  );
}

void showLeakedInfoListPage(
    BuildContext context, List<LeakedInfo> leakInfoList) {
  if (leakInfoList.isEmpty) return;
  BottomPopupCard.show(
    context,
    LeakPreviewPage(leakInfoList: leakInfoList),
  );
}

const double _infoCardWidth = 240;
const double _infoCardMinHeight = 180;

class LeakPreviewPage extends StatefulWidget {
  final List<LeakedInfo> leakInfoList;

  const LeakPreviewPage({Key? key, required this.leakInfoList})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _LeakPreviewPageState();
  }
}

class _LeakPreviewPageState extends State<LeakPreviewPage> {
  int _currentIndex = 0;
  ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retainingPath = widget.leakInfoList[_currentIndex].retainingPath;
    final gcRootType = widget.leakInfoList[_currentIndex].gcRootType;
    final timestamp = widget.leakInfoList[_currentIndex].timestamp;
    final showDate = DateTime.fromMillisecondsSinceEpoch(timestamp!);
    final count = retainingPath.length;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 6 / 7,
        child: Column(
          children: [
            Container(
              height: 40,
              color: Color(0xFF3E5E87),
              padding: EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'GcRoot type:${gcRootType ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '${showDate.month}/${showDate.day} ${showDate.hour}:${showDate.minute}:${showDate.second}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.all(0),
                  controller: _scrollController,
                  itemBuilder: (BuildContext context, int index) {
                    return _node(
                      retainingPath[index],
                      index == 0,
                      index == count - 1,
                      _colorList[index % _colorList.length],
                    );
                  },
                  itemCount: count,
                ),
              ),
            ),
            Visibility(
              visible: true,
              child: Container(
                color: Color(0xFF3F3F3F),
                padding: EdgeInsets.only(bottom: paddingBottom),
                height: 50 + paddingBottom,
                child: Row(
                  children: [
                    Expanded(
                      child: Visibility(
                        visible: _currentIndex > 0,
                        child: TextButton(
                          onPressed: _showPrevious,
                          child: Icon(
                            Icons.navigate_before_rounded,
                            color: Colors.white70,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: _deleteFromDatabase,
                        style: ButtonStyle(
                          padding: MaterialStateProperty.resolveWith(
                              (_) => EdgeInsets.all(0)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_forever_outlined,
                              color: Colors.red.withOpacity(0.8),
                              size: 23,
                            ),
                            Text(
                              '${_currentIndex + 1}/${widget.leakInfoList.length}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.normal,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Visibility(
                        visible: _currentIndex < widget.leakInfoList.length - 1,
                        child: TextButton(
                          onPressed: _showNext,
                          child: Icon(
                            Icons.navigate_next_rounded,
                            color: Colors.white70,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _node(RetainingNode node, bool isFirst, bool isLast, Color lineColor) {
    final hasField = node.parentField != null;
    final hasSourceCodeLocation = node.sourceCodeLocation != null;
    final showSourceCodeLocation = hasSourceCodeLocation &&
        _shouldShowCode(
            node.sourceCodeLocation!, node.leakedNodeType, node.parentField);
    final hasMoreInfo = node.parentKey != null ||
        node.parentIndex != null ||
        showSourceCodeLocation;
    final last = isLast && !hasMoreInfo;
    final height = node.closureInfo != null ? 72.0 : 64.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          // color: node.important ? Color(0xFF4D6673) : Color(0xFF5F5F5F),
          color: isFirst
              ? Color(0xFF9D7E58)
              : node.closureInfo != null
                  ? Color(0xFF4D6673)
                  : Color(0xFF5F5F5F),
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SizedBox(
                height: height,
                width: 30,
                child: CustomPaint(
                  painter: NodeCustomPainter(!isFirst, !last, lineColor),
                ),
              ),
              SizedBox(width: 10),
              if (node.closureInfo == null)
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: node.clazz,
                      children: [
                        if (hasField)
                          TextSpan(
                            text: '.',
                          ),
                        if (hasField)
                          TextSpan(
                            text: node.parentField ?? '',
                            style: TextStyle(
                              // color: node.important ? Color(0xFFE4EB84) : Color(0xFFC0BEEA),
                              color: isFirst
                                  ? Color(0xFFE4EB84)
                                  : Color(0xFFC0BEEA),
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        if (node.leakedNodeType != LeakedNodeType.unknown)
                          TextSpan(
                            text:
                                ' (${_getNodeTypeString(node.leakedNodeType)})',
                            style: TextStyle(
                              color: Color(0xffebcf81),
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                      ],
                      style: TextStyle(
                        // color: node.important ? Color(0xFFFFFFFF) : Color(0xFFF5F5F5),
                        color: isFirst ? Color(0xFFFFFFFF) : Color(0xFFF5F5F5),
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              if (node.closureInfo != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'Closure',
                          children: [
                            TextSpan(
                              text:
                                  '\u00A0\u00A0funName:${node.closureInfo?.closureFunctionName ?? ''}',
                              style: TextStyle(
                                color: Color(0xFFC0BEEA),
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                          style: TextStyle(
                            // color: node.important ? Color(0xFFFFFFFF) : Color(0xFFF5F5F5),
                            color: Color(0xFF7AD1B4),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      RichText(
                        text: TextSpan(
                          text: node.closureInfo?.closureOwnerClass == null
                              ? 'uri:${node.closureInfo?.libraries ?? ''}'
                              : 'class:${node.closureInfo?.closureOwnerClass ?? ''}',
                          children: [
                            if (node.closureInfo?.funLine != null)
                              TextSpan(
                                text:
                                    '#${node.closureInfo?.funLine}:${node.closureInfo?.funColumn}',
                                style: TextStyle(
                                  color: Color(0xFFE7D28F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                          style: TextStyle(
                            // color: node.important ? Color(0xFFE4EB84) : Color(0xFFC0BEEA),
                            color: Color(0xFFC0BEEA),
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return _ClassInfoButton(
                    nodeData: node,
                  );
                },
              ),
            ],
          ),
        ),
        //声明代码
        if (showSourceCodeLocation)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: SizedBox(
                    width: 30,
                    child: Center(
                      child: Container(
                        color: lineColor,
                        width: _strokeWidth,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFFAFAFA), width: 1),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      color: Color(0xFF4C4C4C),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: RichText(
                      text: TextSpan(
                        text: node.sourceCodeLocation?.code ?? '',
                        children: [
                          TextSpan(
                            text: '\n\n${node.sourceCodeLocation?.uri ?? ''}',
                            style: TextStyle(
                              color: Color(0xFFE2E2E2),
                              fontSize: 17,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          if (node.sourceCodeLocation?.lineNum != null)
                            TextSpan(
                              text:
                                  '#${node.sourceCodeLocation?.className ?? ''}',
                              style: TextStyle(
                                color: Color(0xFF7BB2DF),
                                fontSize: 17,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          if (node.sourceCodeLocation?.lineNum != null)
                            TextSpan(
                              text:
                                  '#${node.sourceCodeLocation?.lineNum}:${node.sourceCodeLocation?.columnNum}',
                              style: TextStyle(
                                color: Color(0xFFE7D28F),
                                fontSize: 17,
                                fontWeight: FontWeight.normal,
                              ),
                            )
                        ],
                        style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ],
            ),
          ),
        //列表位置
        if (node.parentIndex != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: SizedBox(
                    width: 30,
                    child: Center(
                      child: Container(
                        color: lineColor,
                        width: _strokeWidth,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFFAFAFA), width: 1),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      color: Color(0xff225fa2),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: RichText(
                      text: TextSpan(
                        text: 'List index: ',
                        children: [
                          TextSpan(
                            text: '${node.parentIndex}',
                            style: TextStyle(
                              color: Color(0xFFE2E2E2),
                              fontSize: 17,
                              fontWeight: FontWeight.normal,
                            ),
                          )
                        ],
                        style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ],
            ),
          ),
        //map 中的 key
        if (node.parentKey != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: SizedBox(
                    width: 30,
                    child: Center(
                      child: Container(
                        color: lineColor,
                        width: _strokeWidth,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFFAFAFA), width: 1),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      color: Color(0xff684327),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: RichText(
                      text: TextSpan(
                        text: 'Map key: ',
                        children: [
                          TextSpan(
                            text: '${node.parentKey}',
                            style: TextStyle(
                              color: Color(0xFFE2E2E2),
                              fontSize: 17,
                              fontWeight: FontWeight.normal,
                            ),
                          )
                        ],
                        style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasMoreInfo)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: 30,
              height: 18,
              child: Center(
                child: Container(
                  color: lineColor,
                  width: _strokeWidth,
                ),
              ),
            ),
          ),
        Container(
          height: 0.8,
          color: Colors.white70,
        ),
      ],
    );
  }

  void _showPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _scrollController.jumpTo(0.0);
      });
    }
  }

  void _showNext() {
    if (_currentIndex < widget.leakInfoList.length - 1) {
      setState(() {
        _currentIndex++;
        _scrollController.jumpTo(0.0);
      });
    }
  }

  void _deleteFromDatabase() {
    final info = widget.leakInfoList[_currentIndex];
    widget.leakInfoList.removeAt(_currentIndex);
    LeakedRecordStore().deleteById(info.timestamp!);
    if (widget.leakInfoList.isEmpty) {
      Navigator.removeRoute(context, ModalRoute.of(context)!);
    } else {
      setState(() {
        _scrollController.jumpTo(0.0);
        _currentIndex = _currentIndex.clamp(0, widget.leakInfoList.length - 1);
      });
    }
  }

  bool _shouldShowCode(SourceCodeLocation sourceCodeLocation,
      LeakedNodeType nodeType, String? parentField) {
    if (parentField == null) return false;
    if (nodeType == LeakedNodeType.element) {
      if (parentField.startsWith('_child@') ||
          parentField.startsWith('_children@')) {
        return false;
      }
    } else if (nodeType == LeakedNodeType.widget) {
      if (parentField.startsWith('_child@') ||
          parentField.startsWith('_children@')) {
        return false;
      }
    }
    return true;
  }

  _getNodeTypeString(LeakedNodeType leakedNodeType) {
    switch (leakedNodeType) {
      case LeakedNodeType.unknown:
        return 'unknown';
      case LeakedNodeType.widget:
        return 'Widget';
      case LeakedNodeType.element:
        return 'Element';
    }
  }
}

const _strokeWidth = 2.3;

class NodeCustomPainter extends CustomPainter {
  final bool hasNext;
  final bool hasPre;
  final Color color;

  final Paint _paint = Paint()
    ..color = Color(0xff1e7ce4)
    ..style = PaintingStyle.fill
    ..strokeWidth = _strokeWidth;

  NodeCustomPainter(this.hasPre, this.hasNext, this.color) {
    _paint.color = color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (hasPre) {
      canvas.drawLine(Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height / 2), _paint);
    } else {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 6, _paint);
    }
    if (hasNext) {
      canvas.drawLine(Offset(size.width / 2, size.height / 2),
          Offset(size.width / 2, size.height), _paint);
      if (hasPre) {
        drawArrow(canvas, size);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NodeCustomPainter oldDelegate) {
    return hasNext != oldDelegate.hasNext;
  }

  void drawArrow(Canvas canvas, Size size) {
    canvas.drawLine(Offset(size.width / 2, size.height / 2),
        Offset(size.width / 2 + 8, size.height / 2 - 10), _paint);
    canvas.drawLine(Offset(size.width / 2, size.height / 2),
        Offset(size.width / 2 - 8, size.height / 2 - 10), _paint);
  }
}

class _ClassInfoButton extends StatefulWidget {
  final RetainingNode nodeData;

  const _ClassInfoButton({Key? key, required this.nodeData}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ClassInfoButtonState();
  }
}

class _ClassInfoButtonState extends State<_ClassInfoButton> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        PopupWindow.show(context, _infoCard(widget.nodeData),
            offset: Offset(-_infoCardWidth, 0), onResult: (_) {
          setState(() {
            _selected = false;
          });
        });
        setState(() {
          _selected = true;
        });
      },
      child: Container(
        width: 50,
        color: Colors.transparent,
        child: Icon(
          Icons.more_horiz,
          color: _selected ? Colors.grey : Colors.white,
        ),
      ),
    );
  }

  Widget _infoCard(RetainingNode node) {
    return Container(
      width: _infoCardWidth,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 9),
      decoration: BoxDecoration(
        color: Color(0xFF686C72),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      constraints: BoxConstraints(
          minHeight: _infoCardMinHeight, maxHeight: _infoCardMinHeight * 2),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.closureInfo?.libraries ?? node.libraries ?? '',
              style: TextStyle(
                color: Color(0xFFFFB74D),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            Text(
              node.closureInfo?.toString() ?? node.string ?? '',
              style: TextStyle(
                color: Color(0xFFDCE9FA),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
