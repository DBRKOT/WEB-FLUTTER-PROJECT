import 'package:flutter/material.dart';

Widget tableCellText(String text, {int maxLines = 2}) {
  return Text(text, overflow: TextOverflow.ellipsis, maxLines: maxLines);
}
