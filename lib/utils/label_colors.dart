import 'package:flutter/material.dart';

const kLabelColors = [
  Color(0xFFE57373),
  Color(0xFF64B5F6),
  Color(0xFF81C784),
  Color(0xFFFFB74D),
  Color(0xFFBA68C8),
  Color(0xFF4DB6AC),
  Color(0xFFA1887F),
  Color(0xFF90A4AE),
];

Color labelColor(String label) =>
    kLabelColors[label.hashCode.abs() % kLabelColors.length];
