import 'package:flutter/material.dart';

import '../theme/palette.dart';

class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.palette.ink3),
    ),
  );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.rows, {super.key});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]],
        ],
      ),
    );
  }
}
