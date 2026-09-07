import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppUsageModel {
  final String appName;
  final String packageName;
  int durationInMinutes;
  String category;
  final Uint8List? iconData;
  bool isBlocked;
  int dailyUsageMinutes;
  List<int> allowedDays;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int? maxDailyMinutes;
  bool isManuallyBlocked;

  AppUsageModel({
    required this.appName,
    required this.packageName,
    required this.durationInMinutes,
    required this.category,
    this.iconData,
    this.isBlocked = false,
    this.dailyUsageMinutes = 0,
    List<int>? allowedDays,
    this.startTime,
    this.endTime,
    this.maxDailyMinutes,
    this.isManuallyBlocked = false,
  }) : allowedDays = allowedDays ?? [1, 2, 3, 4, 5, 6, 7];
}
