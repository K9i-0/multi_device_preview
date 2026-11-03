import 'package:flutter/widgets.dart';

/// Stable controls shared by the example and its native UI regression tests.
abstract final class ExampleKeys {
  static const cart = ValueKey('cart');
  static const cartCount = ValueKey('cart-count');
  static const cartDialog = ValueKey('cart-dialog');
  static const menu = ValueKey('menu');
  static const ordersEmpty = ValueKey('orders-empty');
  static const ordersTab = ValueKey('orders-tab');
  static const search = ValueKey('search');

  static ValueKey<String> addProduct(String product) =>
      ValueKey('add-product-$product');

  static ValueKey<String> product(String product) =>
      ValueKey('product-$product');
}
