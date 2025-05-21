import 'package:flutter/material.dart';
import 'package:myapp/services/database_helper.dart';
import 'package:sqflite/sqflite.dart'; // Not directly used in this file, but likely needed by DatabaseHelper
import 'package:mobile_scanner/mobile_scanner.dart';

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({Key? key}) : super(key: key);

  @override
  _AddSaleScreenState createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final TextEditingController _buyerNameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _products = [];
  Map<int, int> _selectedProducts = {}; // Map of product_id to quantity

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _saveSale() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one product.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final database = await DatabaseHelper.getDatabase();

    await database.transaction((txn) async {
      final saleId = await txn.insert('sales', {
        'buyer_name':
            _buyerNameController.text.isEmpty ? null : _buyerNameController.text,
        'sale_date': _dateController.text.isEmpty
            ? DateTime.now().toIso8601String()
            : _dateController.text,
      });

      for (final entry in _selectedProducts.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        final product = _products.firstWhere((p) => p['id'] == productId);
        final price = product['price'];

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'price': price,
        });
        // Optionally, update product quantity in the products table
        // await txn.rawUpdate('UPDATE products SET initial_quantity = initial_quantity - ? WHERE id = ?', [quantity, productId]);
      }
    });

    print('Sale saved successfully!');
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dateController.text = picked.toIso8601String().split('T')[0];
    }
  }

  Future<void> _fetchProducts() async {
    final database = await DatabaseHelper.getDatabase();
    final products = await database.query('products');
    setState(() {
      _products = products;
    });
  }

  void _toggleProductSelection(int productId, int? currentQuantity) {
    setState(() {
      if (_selectedProducts.containsKey(productId)) {
        // If product already selected, maybe increment quantity or show a message?
        // For now, this logic means clicking again does nothing if already added via scanner.
        // If it was meant to remove, then use: _selectedProducts.remove(productId);
        // Or, if you want to ensure it's added with quantity 1 (or increment):
        _selectedProducts[productId] = (_selectedProducts[productId] ?? 0) + (currentQuantity ?? 1);

      } else {
        _selectedProducts[productId] = currentQuantity ?? 1;
      }
    });
  }

  void _updateProductQuantity(int productId, int quantity) {
    setState(() {
      if (quantity > 0) {
        _selectedProducts[productId] = quantity;
      } else {
        _selectedProducts.remove(productId); // Remove if quantity becomes zero or less
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Sale')),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          MediaQuery.of(context).padding.bottom + 16.0,
        ),
        child: Form(
          key: _formKey, // Use named argument for key
          child: Column(
            children: [
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Sale Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _selectDate,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _buyerNameController,
                decoration: const InputDecoration(
                  labelText: 'Buyer Name (Optional)',
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Select Products:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: IconButton( // Corrected closing parenthesis (comment from original)
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        _showProductSelectionDialog(context);
                      }, // Corrected semicolon (comment from original)
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => MobileScanner(
                            onDetect: (BarcodeCapture barcodeCapture) {
                              if (barcodeCapture.barcodes.isNotEmpty &&
                                  barcodeCapture.barcodes.first.rawValue != null) {
                                Navigator.of(context).pop(); // Dismiss scanner
                                final scannedBarcode =
                                    barcodeCapture.barcodes.first.rawValue!;
                                DatabaseHelper.getDatabase().then((database) {
                                  database.query(
                                    'products',
                                    where: 'barcode = ?',
                                    whereArgs: [scannedBarcode],
                                  ).then((product) {
                                    if (product.isNotEmpty) {
                                      _toggleProductSelection(
                                          product.first['id'] as int, 1);
                                    } else {
                                      if (mounted) { // Check if widget is still in tree
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Product not found!')));
                                      }
                                    }
                                  });
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Expanded( // Use Expanded to allow the list to take available space
                child: ListView.builder(
                  itemCount: _selectedProducts.length,
                  itemBuilder: (context, index) {
                    final productId = _selectedProducts.keys.elementAt(index);
                    final quantity = _selectedProducts.values.elementAt(index);
                    // Ensure product exists in _products list before accessing it
                    final product = _products.firstWhere(
                        (p) => p['id'] == productId,
                        orElse: () => {'name': 'Unknown Product', 'price': 0.0}); // Fallback

                    return ListTile(
                      title: Text(product['name'] as String),
                      subtitle: Text('\$${(product['price'] as num?)?.toStringAsFixed(2) ?? 'N/A'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60, // Adjust width as needed
                            child: TextFormField(
                              initialValue: quantity.toString(),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8.0)
                              ),
                              onChanged: (value) {
                                final newQuantity = int.tryParse(value);
                                if (newQuantity != null) { // Allow 0 to remove via update
                                  _updateProductQuantity(productId, newQuantity);
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () {
                              _updateProductQuantity(productId, 0); // Or directly remove
                              // setState(() {
                              //   _selectedProducts.remove(productId);
                              // });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _saveSale,
                child: const Text('Save Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProductSelectionDialog(BuildContext context) async {
    // Filter out already selected products from the dialog
    final availableProducts = _products.where((p) => !_selectedProducts.containsKey(p['id'])).toList();

    if (availableProducts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All products already selected or no products available.'),
        ),
      );
      return;
    }

    final selectedProduct = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Product'),
          content: SingleChildScrollView(
            child: ListBody(
              children: availableProducts.map((product) {
                return ListTile(
                  title: Text(product['name'] as String),
                  trailing: Text('\$${(product['price'] as num?)?.toStringAsFixed(2) ?? 'N/A'}'),
                  onTap: () {
                    Navigator.of(context).pop(product);
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (selectedProduct != null) {
      setState(() {
        final productId = selectedProduct['id'] as int;
        // This check might be redundant if availableProducts is used, but good for safety
        if (!_selectedProducts.containsKey(productId)) {
          _selectedProducts[productId] = 1; // Default quantity to 1
        }
      });
    }
  }
}