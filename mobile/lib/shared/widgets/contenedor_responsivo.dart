import 'package:flutter/material.dart';

class ContenedorResponsivo extends StatelessWidget {
  const ContenedorResponsivo({
    super.key,
    required this.child,
    this.anchoMaximo = 760,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double anchoMaximo;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: anchoMaximo),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
