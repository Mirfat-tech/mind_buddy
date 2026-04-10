import 'package:flutter/material.dart';

class BubbleEntry {
  BubbleEntry({
    required this.id,
    this.text = '',
    this.solutionText = '',
    required this.offset,
    required this.createdAt,
  });

  final String id;
  String text;
  String solutionText;
  Offset offset;
  final DateTime createdAt;
}
