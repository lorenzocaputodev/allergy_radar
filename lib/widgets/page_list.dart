import 'package:flutter/material.dart';

/// Contenuto a scorrimento di una pagina aperta sopra le schede. Con un [padding] esplicito ListView non
/// aggiunge più le aree di sistema (barre, notch): qui si sommano al margine, anche ai lati.
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
