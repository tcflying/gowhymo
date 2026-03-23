import 'package:flutter/material.dart';

const appVersion = '1.0.0';
const appServer = 'https://zhcj.fzjuding.com:65533';
const qwenUrl = '$appServer/gowhymo/llm';
const qwenModel = 'Qwen/Qwen3-32B-AWQ';

const double inputBorderRadius = 18;
const double btnBorderRadius = 18;
const double cardBorderRadius = 24;
const double smallElementBorderRadius = 16;

final Map<Color, String> kidColorMapString = {
  Colors.redAccent: 'redAccent',
  Colors.yellowAccent: 'yellowAccent',
  Colors.purpleAccent: 'purpleAccent',
  Colors.blueAccent: 'blueAccent',
  Colors.cyanAccent: 'cyanAccent',
  Colors.greenAccent: 'greenAccent',
  Colors.limeAccent: 'limeAccent',
  Colors.pinkAccent: 'pinkAccent',
  Colors.tealAccent: 'tealAccent',
  Colors.orangeAccent: 'orangeAccent',
};

final Map<String, Color> kidColorStringMapColor = {
  'redAccent': Colors.redAccent,
  'yellowAccent': Colors.yellowAccent,
  'purpleAccent': Colors.purpleAccent,
  'blueAccent': Colors.blueAccent,
  'cyanAccent': Colors.cyanAccent,
  'greenAccent': Colors.greenAccent,
  'limeAccent': Colors.limeAccent,
  'pinkAccent': Colors.pinkAccent,
  'tealAccent': Colors.tealAccent,
  'orangeAccent': Colors.orangeAccent,
};

final List<Color> kidColors = kidColorMapString.keys.map((e) => e).toList();
