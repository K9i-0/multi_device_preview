import 'package:flutter/material.dart';

/// A small shop-like app with tabs, a list, a search field, a detail page and
/// a dialog, to look at layouts and try input mirroring across devices.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'multi_device_preview example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

const _products = [
  'Espresso',
  'Cappuccino with oat milk and an extra shot',
  'Flat white',
  'Matcha latte',
  'Cold brew',
  'Hojicha latte',
  'Chai latte with cinnamon',
  'Hot chocolate',
  'Affogato',
  'Iced americano',
  'Caramel macchiato',
  'Mocha',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  int _cart = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = [
      for (final product in _products)
        if (product.toLowerCase().contains(_query.toLowerCase())) product,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffee stand'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cart'),
                content: Text('$_cart items in your cart.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            icon: Badge(
              label: Text('$_cart'),
              isLabelVisible: _cart > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          ListView(
            key: const ValueKey('menu'),
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const ValueKey('search'),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Search the menu',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              for (final product in products)
                ListTile(
                  leading: CircleAvatar(child: Text(product[0])),
                  title: Text(product),
                  subtitle: const Text('Freshly made · ¥480'),
                  trailing: IconButton(
                    tooltip: 'Add $product',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _cart++),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => DetailPage(product: product),
                    ),
                  ),
                ),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Nothing matches your search.')),
                ),
            ],
          ),
          const Center(child: Text('No orders yet')),
          const Center(child: Text('Signed in as guest')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_cafe), label: 'Menu'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key, required this.product});

  final String product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.coffee, size: 64),
            ),
          ),
          const SizedBox(height: 16),
          Text(product, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Made to order with beans roasted this week. Long names and '
            'large text sizes should wrap instead of overflowing.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to the menu'),
          ),
        ],
      ),
    );
  }
}
