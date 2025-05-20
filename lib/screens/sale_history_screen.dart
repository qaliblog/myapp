import 'package:flutter/material.dart';
import 'package:myapp/services/database_helper.dart';
import 'dart:io';
import 'package:myapp/utils/receipt_generator.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:html_to_image/html_to_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
class SaleHistoryScreen extends StatefulWidget {
  @override
  _SaleHistoryScreenState createState() => _SaleHistoryScreenState();
}

class _SaleHistoryScreenState extends State<SaleHistoryScreen> {
  Map<String, List<Map<String, dynamic>>> _salesByBuyer = {};
  final GlobalKey _receiptKey = GlobalKey();
  List<bool> _expandedState = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSalesHistory();
  }

  Future<void> _fetchSalesHistory() async {
    try {
      final DatabaseHelper dbHelper = DatabaseHelper();
      final Map<String, List<Map<String, dynamic>>> sales = await dbHelper.getSalesByBuyer();

      setState(() {
        _salesByBuyer = sales;
        _expandedState = List<bool>.filled(_salesByBuyer.length, false);
        _errorMessage = null; // Clear any previous errors
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching sales history: $e';
      });
    }
  }

  Future<Uint8List?> _generateAndCaptureReceipt() async {
    if (_salesByBuyer.isEmpty) {
      // Optionally show a message that there's no data to generate a receipt for
      print('No sales data to generate receipt.');
      return null;
    }

    try {
      // Generate HTML content for the receipt
      String htmlContent = _generateReceiptHtml();

      // Convert HTML to image using html_to_image
      final imageBytes = await HtmlToImage.tryConvertToImage(content: htmlContent);
      return imageBytes;
    } on Exception catch (e) {
      print('Error generating and capturing receipt: $e');
      return null;
    }
  }

  Future<Uint8List?> _generateAndCaptureBuyerReceipt(String buyerName, List<Map<String, dynamic>> sales) async {
    if (sales.isEmpty) {
      print('No sales data to generate receipt for $buyerName.');
 return null;
    }

    try {
      // Generate HTML content for the receipt for this buyer
      String htmlContent = ReceiptGenerator.generateBuyerReceiptHtml(buyerName, sales);

      // Convert HTML to image using html_to_image
      final imageBytes = await HtmlToImage.tryConvertToImage(content: htmlContent);
 return imageBytes;
    } on Exception catch (e) {
      print('Error generating and capturing receipt for $buyerName: $e');
 return null;
    }
  }

  void _downloadReceipt(Uint8List bytes) {
    _downloadReceiptMobile(bytes);
  }

  Future<void> _downloadReceiptMobile(Uint8List bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/receipt.png';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(filePath)], text: 'Here is your sales receipt.');
  }

  // Helper method to build the list of sale items for a buyer
  String _generateReceiptHtml() {
    // Ensure _salesByBuyer is a valid argument for generateReceiptHtml
    return ReceiptGenerator.generateReceiptHtml(_salesByBuyer);
  }

  List<Widget> _buildSaleSection(String buyerName, List<Map<String, dynamic>> sales) {
    List<Widget> widgets = sales.map((sale) {
 return ListTile(
 key: UniqueKey(), // Add a unique key if needed for list items
        title: Text(sale['product_name']),
        subtitle: Text('Quantity: ${sale['quantity']}'),
        trailing: Text('\$${sale['item_price'].toStringAsFixed(2)}'),

      );
 // Removed .toList() here, will add it at the end
    }).toList();
 return widgets; // Ensure a List<Widget> is always returned
  }

  @override
  Widget build(BuildContext context) {
    final buyers = _salesByBuyer.keys.toList();
    return Scaffold( // Corrected parenthesis here
      appBar: AppBar(
        title: const Text('Sale History'),
      ),
      body: _errorMessage != null
          ? Center(
              child: Text(
                'Error: ${_errorMessage!}',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
 ),
            )
          : _salesByBuyer.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      ..._salesByBuyer.keys.map((buyer) {
 return ExpansionTile(
 title: Text('Sales for $buyer'),
 children: [
 ..._buildSaleSection(buyer, _salesByBuyer[buyer]!), // Use the new build method
              Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Corrected parameter name
                child: ElevatedButton(
 onPressed: () async {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text('Generating and downloading receipt for $buyer...')),
 );
 final bytes = await _generateAndCaptureBuyerReceipt(buyer, _salesByBuyer[buyer]!);
 if (bytes != null) {
 _downloadReceipt(bytes);
                      }
                    },
 child: Text('Download Receipt for $buyer'),
 ),
 ),
 ], // Close children list
 ); // Close ExpansionTile
 }).toList(),

                      Padding(
 padding: const EdgeInsets.all(16.0), // Add padding for the total)
 child: Text( // Display Grand Total
                           'Grand Total: \$${_calculateGrandTotal().toStringAsFixed(2)}', // Calculate and display grand total
 style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                          ),
 ),
 ],
 ),
 ),
    );
  }

  double _calculateGrandTotal() {
    double grandTotal = 0.0;
    _salesByBuyer.values.expand((sales) => sales).forEach((sale) {
      grandTotal += (sale['quantity'] as num? ?? 0) * (sale['item_price'] as num? ?? 0.0);
    });
    return grandTotal;
  }
}