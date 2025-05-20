import 'package:flutter/material.dart';
import 'package:myapp/services/database_helper.dart';
import 'package:myapp/screens/add_personal_transaction_screen.dart';

class PersonalSection extends StatefulWidget {
  const PersonalSection({Key? key}) : super(key: key);

  @override
  _PersonalSectionState createState() => _PersonalSectionState();
}

class _PersonalSectionState extends State<PersonalSection> {
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    final database = await DatabaseHelper.getDatabase();
    final transactions = await database.query(DatabaseHelper.PERSONAL_TRANSACTIONS_TABLE);
    setState(() {
      _transactions = transactions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Transactions'),
      ),
      body: ListView.builder(
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return ListTile(
            title: Text('${transaction['type']}: ${transaction['category']}'),
            subtitle: Text(transaction['description'] ?? ''),
            trailing: Text('${transaction['amount'].toStringAsFixed(2)} on ${transaction['date']}'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPersonalTransactionScreen()),
          ).then((_) => _fetchTransactions()); // Refresh list after adding transaction
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}