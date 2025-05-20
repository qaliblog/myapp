import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:sqflite/sqflite.dart'; // Import sqflite for Database type
import 'package:myapp/services/database_helper.dart'; // Import DatabaseHelper

class AddPersonalTransactionScreen extends StatefulWidget {
  const AddPersonalTransactionScreen({Key? key}) : super(key: key);

  @override
  _AddPersonalTransactionScreenState createState() =>
      _AddPersonalTransactionScreenState();
}

class _AddPersonalTransactionScreenState
    extends State<AddPersonalTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _transactionType = 'Expense'; // Default to Expense
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Database database = await DatabaseHelper.getDatabase();

    Map<String, dynamic> transactionData = {
      'type': _transactionType,
      'category': _categoryController.text,
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'description': _descriptionController.text,
    };

    await database.insert(
        DatabaseHelper.PERSONAL_TRANSACTIONS_TABLE, transactionData);

    Navigator.pop(context);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            // Use ListView for scrolling if content exceeds screen size
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _transactionType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: <String>['Income', 'Expense'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _transactionType = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              ListTile(
                title: Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3, // Allow multiple lines for description
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _saveTransaction,
                child: const Text('Save Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}