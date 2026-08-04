import 'package:flutter/material.dart';

abstract final class AppRadii {
  static const small = BorderRadius.all(Radius.circular(10));
  static const medium = BorderRadius.all(Radius.circular(16));
  static const large = BorderRadius.all(Radius.circular(24));
  static const pill = BorderRadius.all(Radius.circular(999));
}
