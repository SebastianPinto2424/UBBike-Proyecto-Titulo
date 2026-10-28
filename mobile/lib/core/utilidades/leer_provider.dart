import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

T leerProvider<T>(BuildContext context, ProviderListenable<T> provider) {
  return ProviderScope.containerOf(context, listen: false).read(provider);
}
