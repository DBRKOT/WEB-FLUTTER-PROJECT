import 'package:flutter/material.dart';

enum ScreenSize { compact, medium, expanded }

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 600) {
    return ScreenSize.compact;
  }
  if (width < 1200) {
    return ScreenSize.medium;
  }
  return ScreenSize.expanded;
}
