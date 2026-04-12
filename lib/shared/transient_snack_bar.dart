import 'package:flutter/material.dart';

void showTransientSnackBar(
  BuildContext context,
  SnackBar snackBar,
) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(snackBar);
}

void clearTransientSnackBar(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
}
