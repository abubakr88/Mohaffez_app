import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DSText {
  DSText._();

  static TextStyle _arabic({
    required double size,
    required FontWeight weight,
    Color color = const Color(0xFF111827),
    double? height,
  }) =>
      GoogleFonts.ibmPlexSansArabic(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle _latin({
    required double size,
    required FontWeight weight,
    Color color = const Color(0xFF111827),
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle _resolve(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
  }) =>
      resolve(context, size: size, weight: weight, color: color, height: height);

  static TextStyle resolve(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final c = color ?? const Color(0xFF111827);
    return isRtl
        ? _arabic(size: size, weight: weight, color: c, height: height)
        : _latin(size: size, weight: weight, color: c, height: height);
  }

  static TextStyle display(BuildContext context, {Color? color}) =>
      _resolve(context, size: 32, weight: FontWeight.w700, color: color, height: 1.2);

  static TextStyle h1(BuildContext context, {Color? color}) =>
      _resolve(context, size: 24, weight: FontWeight.w700, color: color, height: 1.3);

  static TextStyle h2(BuildContext context, {Color? color}) =>
      _resolve(context, size: 20, weight: FontWeight.w600, color: color, height: 1.35);

  static TextStyle h3(BuildContext context, {Color? color}) =>
      _resolve(context, size: 16, weight: FontWeight.w600, color: color, height: 1.4);

  static TextStyle body(BuildContext context, {Color? color}) =>
      _resolve(context, size: 14, weight: FontWeight.w400, color: color, height: 1.5);

  static TextStyle bodyMedium(BuildContext context, {Color? color}) =>
      _resolve(context, size: 14, weight: FontWeight.w500, color: color, height: 1.5);

  static TextStyle caption(BuildContext context, {Color? color}) =>
      _resolve(context, size: 12, weight: FontWeight.w400, color: color, height: 1.4);

  static TextStyle micro(BuildContext context, {Color? color}) =>
      _resolve(context, size: 11, weight: FontWeight.w500, color: color, height: 1.4);
}
