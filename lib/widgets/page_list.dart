import 'package:flutter/material.dart';

/// Contenuto a scorrimento di una pagina aperta sopra le schede.
///
/// ListView aggiunge da sola le aree di sistema (barra di navigazione, notch) solo se non riceve
/// un [padding]: qui si sommano al margine della pagina, anche ai lati per l'orizzontale.
/// Le si legge dal contesto del corpo, dove l'AppBar ha già tolto quella in alto.
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
