import 'package:flutter/material.dart';
import 'package:myapp/services/database_helper.dart';
import 'package:myapp/screens/add_product_screen.dart';
import 'package:myapp/screens/add_sale_screen.dart';
import 'package:myapp/screens/add_purchase_screen.dart';
import 'package:myapp/screens/purchase_history_screen.dart';
import 'package:myapp/screens/sale_history_screen.dart';

class ShopSection extends StatefulWidget { // Removed const from constructor as it's a StatefulWidget
  const ShopSection({Key? key}) : super(key: key);

  @override
  _ShopSectionState createState() => _ShopSectionState();
}

class _ShopSectionState extends State<ShopSection> {
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final database = await DatabaseHelper.getDatabase();
    final products = await database.query('products');
    setState(() {
      _products = products;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history), // Or Icons.receipt_long
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SaleHistoryScreen()));
            },
          ),
           IconButton(
            icon: const Icon(Icons.receipt), // Use a different icon for sales history
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PurchaseHistoryScreen()));
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return ListTile(
            title: Text(product['name']),
            trailing: Text('\$${product['price'].toStringAsFixed(2)}'),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddProductScreen()),
              ).then((_) => _fetchProducts()); // Refresh list after adding product
            },
            heroTag: 'addProductFab', // Add a unique heroTag
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16.0), // Add spacing between buttons
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddSaleScreen()),
              );
            },
            heroTag: 'addSaleFab', // Add a unique heroTag
            child: const Icon(Icons.shopping_cart), // Use a different icon for add sale
          ),
          const SizedBox(height: 16.0), // Add spacing between buttons
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPurchaseScreen()),
              );
            },
            heroTag: 'addPurchaseFab', // Add a unique heroTag
            child: const Icon(Icons.local_shipping), // Use a different icon for add purchase
          ),
        ],
      ),
    );
  }
}