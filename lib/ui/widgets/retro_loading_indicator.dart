import 'package:flutter/material.dart';

class RetroLoadingIndicator extends StatelessWidget {
  final double size;

  const RetroLoadingIndicator({
    super.key,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/loading.gif',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
