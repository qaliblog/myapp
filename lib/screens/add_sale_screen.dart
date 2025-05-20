import 'package:flutter/material.dart';
import 'package:myapp/services/database_helper.dart';
import 'package:sqflite/sqflite.dart';

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
      // Show an error or a snackbar to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one product.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final database = await DatabaseHelper.getDatabase();

    // Start a transaction for atomic operations
    await database.transaction((txn) async {
      // Insert into the sales table
      final saleId = await txn.insert('sales', {
        'buyer_name':
            _buyerNameController.text.isEmpty
                ? null
                : _buyerNameController.text,
        'sale_date':
            _dateController.text.isEmpty
                ? DateTime.now().toIso8601String()
                : _dateController.text, // Store date as string
      });

      // Insert into the sale_items table for each selected product
      for (final entry in _selectedProducts.entries) {
        final productId = entry.key;
        final quantity = entry.value;

        // Get the price of the product from the fetched list
        final product = _products.firstWhere((p) => p['id'] == productId);
        final price = product['price'];

        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productId,
          'quantity': quantity,
          'price': price, // Store the price at the time of sale
        });

        // Optionally, update product quantity in the products table
        // This depends on whether you want to track inventory depletion
        // await txn.rawUpdate('UPDATE products SET initial_quantity = initial_quantity - ? WHERE id = ?', [quantity, productId]);
      }
    });

    print('Sale saved successfully!');
    Navigator.pop(context); // Navigate back after saving
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // Format the date as needed, e.g., 'yyyy-MM-dd'
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
        _selectedProducts.remove(productId);
      } else {
        _selectedProducts[productId] =
            currentQuantity ?? 1; // Default quantity to 1
      }
    });
  }

  void _updateProductQuantity(int productId, int quantity) {
    setState(() {
      _selectedProducts[productId] = quantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Sale')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Sale Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _selectDate, // Open date picker on tap
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                // Added TextFormField wrapper
                controller: _buyerNameController,
                decoration: const InputDecoration(
                  labelText: 'Buyer Name (Optional)',
                ), // Corrected decoration placement
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Select Products:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final productId = product['id'] as int;
                    final isSelected = _selectedProducts.containsKey(productId);
                    final currentQuantity = _selectedProducts[productId];

                    return ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          if (value == true) {
                            _toggleProductSelection(
                              productId,
                              1,
                            ); // Default to 1 when selected
                          } else {
                            _toggleProductSelection(
                              productId,
                              null,
                            ); // Quantity doesn't matter when deselecting
                          }
                        },
                      ),
                      title: Text(product['name']),
                      subtitle:
                          isSelected
                              ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Quantity: '),
                                  SizedBox(
                                    width: 80, // Adjust width as needed
                                    child: TextFormField(
                                      initialValue:
                                          currentQuantity?.toString() ?? '1',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true, // Reduces vertical space
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ), // Adjust padding
                                      ),
                                      onChanged: (value) {
                                        final quantity = int.tryParse(value);
                                        if (quantity != null && quantity > 0) {
                                          _updateProductQuantity(
                                            productId,
                                            quantity,
                                          );
                                        } else if (quantity == 0) {
                                          // Optionally remove if quantity is 0
                                          _selectedProducts.remove(productId);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              )
                              : null,
                      trailing: Text(
                        '\$${product['price'].toStringAsFixed(2)}',
                      ),
                      onTap: () {
                        _toggleProductSelection(
                          productId,
                          product['initial_quantity'],
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24.0),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ElevatedButton(
                  onPressed: _saveSale,
                  child: const Text('Save Sale'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
