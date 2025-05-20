import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:myapp/services/database_helper.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:html_to_image/html_to_image.dart';
import 'package:flutter_html/flutter_html.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({Key? key}) : super(key: key);

  @override
  _PurchaseHistoryScreenState createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<Map<String, dynamic>> _purchases = [];

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    final database = await DatabaseHelper.getDatabase();
    final purchases = await database.query(DatabaseHelper.PURCHASES_TABLE);
    setState(() {
      _purchases = purchases;
    });
  }

  Future<String> _generatePurchaseReceiptHtml(Map<String, dynamic> purchase, List<Map<String, dynamic>> purchaseItems) async {
    String htmlContent = '''
  <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h2 { text-align: center; }
        .receipt-details { margin-bottom: 20px; }
        .item { margin-bottom: 10px; padding-bottom: 10px; border-bottom: 1px solid #eee; }
        .item span { display: inline-block; width: 150px; }
        .total { font-weight: bold; }
      </style>
    </head>
    <body>
      <h2>Purchase Receipt</h2>
      <div class="receipt-details">
        <p><strong>Date:</strong> ${purchase['purchase_date']}</p>
        <p><strong>Supplier:</strong> ${purchase['supplier'] as String? ?? 'N/A'}</p>
      </div>
      <h3>Items:</h3>
      ${purchaseItems.map((item) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final subtotal = quantity * price;
        return '''
        <div class="item">
          <span>${item['product_name']}</span>
          <span>Qty: ${quantity.toStringAsFixed(2)}</span>
          <span>Price: \$${price.toStringAsFixed(2)}</span>
          <span>Subtotal: \$${subtotal.toStringAsFixed(2)}</span>
       </div>
      ''';}).join('')}
      <p class="total">Total: \$${((purchase['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}</p>
    </body>
  </html>
''';
    return htmlContent;
  }

  Future<Uint8List?> _generateAndCapturePurchaseReceipt(int purchaseId) async {
    try {
      final database = await DatabaseHelper.getDatabase();
      final purchaseResult = await database.query(
        DatabaseHelper.PURCHASES_TABLE,
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      if (purchaseResult.isEmpty) {
        return null;
      }

      final purchase = purchaseResult.first;
      final purchaseItems = await database.query(
        DatabaseHelper.PURCHASE_ITEMS_TABLE,
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );

      String htmlContent = await _generatePurchaseReceiptHtml(purchase, purchaseItems);
      final imageBytes = await HtmlToImage.tryConvertToImage(content: htmlContent);
      return imageBytes;
    } catch (e) {
      print('Error generating and capturing purchase receipt: $e');
      return null;
    }
  }

  Future<void> _shareReceipt(int purchaseId) async {
    try {
      final database = await DatabaseHelper.getDatabase();

      // Fetch purchase details
      final purchaseResult = await database.query(
        DatabaseHelper.PURCHASES_TABLE,
        where: 'id = ?',
        whereArgs: [purchaseId],
      );

      if (purchaseResult.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase not found.')),
        );
        return;
      }

      final purchase = purchaseResult.first;

      // Fetch purchase items
      final purchaseItems = await database.query(
        DatabaseHelper.PURCHASE_ITEMS_TABLE,
        where: 'purchase_id = ?',
        whereArgs: [purchaseId],
      );

      final pngBytes = await _generateAndCapturePurchaseReceipt(purchaseId);
      

      if (pngBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture receipt image.')),
        );
        return;
      }      
      
      // Save the image to a temporary file
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/receipt_$purchaseId.png';
      final file = File(imagePath);
      await file.writeAsBytes(pngBytes!);

      // Share the image file
      ShareResult shareResult = await Share.shareXFiles([XFile(imagePath)], text: 'Purchase Receipt');

      // Optional: Show feedback to the user
      if (shareResult.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt shared successfully!')),
        );
      } else if (shareResult.status == ShareResultStatus.dismissed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing dismissed.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share receipt.')),
        );
      }


    } catch (e) {
      print('Error sharing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download receipt: $e')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase History'),
      ),
      body: _purchases.isEmpty
          ? const Center(
              child: Text('No purchases recorded yet.'),
            )
          : ListView.builder(
              itemCount: _purchases.length,
              itemBuilder: (context, index) {
                final purchase = _purchases[index];
                return ListTile(
                  title: Text('Date: ${purchase['purchase_date']}'),
                  subtitle: Text(
                      'Supplier: ${purchase['supplier'] as String? ?? 'N/A'}\nTotal: \$${((purchase['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                  // You might want to add onTap to view purchase details
                   trailing: IconButton( // Moved trailing inside the ListTile
                    icon: const Icon(Icons.download),
                    onPressed: () => _shareReceipt(purchase['id'] as int),
                  ),
                );
              },
            ),
    );
  }
}