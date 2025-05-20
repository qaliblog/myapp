import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:myapp/services/database_helper.dart';
import 'package:intl/intl.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({Key? key}) : super(key: key);

  @override
  _AddPurchaseScreenState createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
   DateTime? _selectedDate;

  List<Map<String, dynamic>> _products = [];
  Map<int, Map<String, dynamic>> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _supplierController.dispose();
    _selectedProducts.forEach((key, value) {
      (value['quantityController'] as TextEditingController).dispose();
      (value['priceController'] as TextEditingController).dispose();
    });
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    final database = await DatabaseHelper.getDatabase();
    final products = await database.query('products');
    setState(() {
      _products = products;
      // Initialize selected products map with controllers
      for (var product in products) {
        _selectedProducts[product['id'] as int] = {
          'product': product,
          'isSelected': false,
          'quantityController': TextEditingController(),
          // Initialize purchase price controller, possibly with a default or empty
          'priceController': TextEditingController(),
        };
      }
    });
  }

  void _savePurchase() async {
    if (_selectedProducts.values.every((product) => product['isSelected'] == false)) {
      // Show a message if no products are selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one product.')),
      );
      return;
    }

    final database = await DatabaseHelper.getDatabase();
    double totalAmount = 0;

    try {
      await database.transaction((txn) async {
        // Insert into purchases table
        final purchaseId = await txn.insert('purchases', {
          'purchase_date': _dateController.text.isEmpty ? DateTime.now().toIso8601String() : _dateController.text,
          'supplier': _supplierController.text,
          'total_amount': 0.0, // Will update later
        });

        // Insert into purchase_items table and calculate total amount
        for (var entry in _selectedProducts.entries) {
          final productId = entry.key;
          final productData = entry.value;

          if (productData['isSelected']) {
            final quantity = int.tryParse(productData['quantityController'].text) ?? 0;
            final price = double.tryParse(productData['priceController'].text) ?? 0.0;

            if (quantity > 0 && price >= 0) {
              await txn.insert('purchase_items', {
                'purchase_id': purchaseId,
                'product_id': productId,
                'quantity': quantity,
                'price': price,
              });
              totalAmount += quantity * price;

              // Update product initial_quantity
              await txn.rawUpdate(
                'UPDATE products SET initial_quantity = initial_quantity + ? WHERE id = ?',
                [quantity, productId],
              );
            }
          }
        }

        // Update total_amount in the purchases table
        await txn.update(
          'purchases',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [purchaseId],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase saved successfully!')),
      );
      Navigator.pop(context); // Navigate back after saving
    } catch (e) {
      print('Error saving purchase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save purchase: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Format the date and update the text controller
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      });
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Purchase')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Purchase Date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () {
                  _selectDate(context);
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _supplierController,
                decoration: const InputDecoration(labelText: 'Supplier (Optional)'),
              ),
              const SizedBox(height: 24.0),
              const Text('Select Products:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8.0),
              if (_products.isEmpty)
                const Center(child: Text('No products found. Add products first.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final productId = product['id'] as int;
                    final productData = _selectedProducts[productId]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: productData['isSelected'],
                                  onChanged: (bool? value) {
                                    setState(() {
                                      productData['isSelected'] = value ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    product['name'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            if (productData['isSelected'])
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: productData['quantityController'],
                                        decoration: const InputDecoration(labelText: 'Quantity'),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 16.0),
                                    Expanded(
                                      child: TextFormField(
                                        controller: productData['priceController'],
                                        decoration: const InputDecoration(labelText: 'Purchase Price'),
                                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _savePurchase,
                child: const Text('Save Purchase'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}