class ReceiptGenerator {
  static String generateReceiptHtml(Map<String, List<Map<String, dynamic>>> salesByBuyer) {
    if (salesByBuyer.isEmpty) {
      return "<p>No sales data provided.</p>";
    }
    return _generateHtml(salesByBuyer: salesByBuyer);
  }

  static String generateBuyerReceiptHtml(String buyerName, List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return "<p>No sales data provided for $buyerName.</p>";
    }

    // Create a temporary map containing only the sales for the specific buyer
    Map<String, List<Map<String, dynamic>>> salesForBuyer = {buyerName: sales};

    // Generate HTML for this single buyer, excluding the grand total
    return _generateHtml(salesByBuyer: salesForBuyer, includeGrandTotal: false);
  }

  static String _generateHtml({
    required Map<String, List<Map<String, dynamic>>> salesByBuyer,
    bool includeGrandTotal = true,
  }) {
    if (salesByBuyer.isEmpty) {
      return "<p>No sales data provided.</p>";
    }

    StringBuffer htmlBuffer = StringBuffer();

    // Add the HTML header and basic structure
    htmlBuffer.write('''
    <!DOCTYPE html>
    <html>
    <head>
      <title>Sales Receipt</title>
      <style>
        body { font-family: sans-serif; margin: 20px; }
        h2 { text-align: center; margin-bottom: 15px; }
        h3 { margin-top: 20px; margin-bottom: 10px; }
        .sale-section { margin-bottom: 30px; border-bottom: 1px dashed #ccc; padding-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .total { font-weight: bold; }
        .footer { margin-top: 30px; text-align: center; font-size: 0.9em; color: #555; }
      </style>
    </body>
    </html>
    </head>
    <body>
      <h2>Sales Receipts</h2>
    ''');

    // Iterate over buyers and their sales
  salesByBuyer.forEach((buyerName, sales) {
    htmlBuffer.write('<div class="sale-section">');
    htmlBuffer.write('<h3>Sales for $buyerName</h3>');

    if (sales.isNotEmpty) {
      htmlBuffer.write('<table>');
      htmlBuffer.write('<thead><tr><th>Product</th><th>Quantity</th><th>Price</th><th>Subtotal</th></tr></thead>');
      htmlBuffer.write('<tbody>');

      double buyerTotal = 0;
      for (var sale in sales) {
        final String productName = sale['product_name'] ?? 'Unknown Product';
        final int quantity = (sale['quantity'] as num?)?.toInt() ?? 0;
        final double price = (sale['item_price'] as num?)?.toDouble() ?? 0.0; // Assuming 'item_price' based on previous context
        final double subtotal = quantity * price;
        buyerTotal += subtotal;
        htmlBuffer.write('<tr><td>$productName</td><td>$quantity</td><td>\$${price.toStringAsFixed(2)}</td><td>\$${subtotal.toStringAsFixed(2)}</td></tr>');
      }

      htmlBuffer.write('</tbody>');
      htmlBuffer.write('<tr><td colspan="3" class="total">Total for $buyerName:</td><td class="total">\$${buyerTotal.toStringAsFixed(2)}</td></tr>'); // Corrected colspan
      htmlBuffer.write('</table>');

      htmlBuffer.write('</div>'); // Close sale-section
    } else {
      htmlBuffer.write('<p>No sales recorded for $buyerName.</p>');
      htmlBuffer.write('</div>'); // Close sale-section
    }
  });

    // Add the grand total section if requested
  if (includeGrandTotal) {
    double grandTotal = salesByBuyer.values.expand((sales) => sales).map((sale) => ((sale['quantity'] as num?)?.toDouble() ?? 0.0) * ((sale['item_price'] as num?)?.toDouble() ?? 0.0)).fold(0.0, (sum, subtotal) => sum + subtotal);
    htmlBuffer.write('<div class="total">Grand Total: \$${grandTotal.toStringAsFixed(2)}</div>');
  }

  // Close body and html tags
    // Add the footer
  htmlBuffer.write('''
      <div class="footer">
        <p>Thank you for your business!</p>
      </div>
    </body>
    </html>
   ''');
  return htmlBuffer.toString();
}
}