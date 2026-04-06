import 'package:flutter/material.dart';

const kBrandGradient = LinearGradient(
  colors: [Color(0xFF3CC8C4), Color(0xFF44D494)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const GradientText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => kBrandGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}
