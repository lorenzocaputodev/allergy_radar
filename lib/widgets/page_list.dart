import 'package:flutter/material.dart';

class PageList extends StatelessWidget {
  const PageList({super.key, required this.padding, required this.children});

  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return ListView(padding: padding + EdgeInsets.fromLTRB(safe.left, 0, safe.right, safe.bottom), children: children);
  }
}
