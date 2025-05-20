import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String DB_NAME = 'expense_assistant.db';
  static const String PERSONAL_TRANSACTIONS_TABLE = 'personal_transactions';
  static const String SALES_TABLE = 'sales';
  static const String SALE_ITEMS_TABLE = 'sale_items';
  static const String PRODUCTS_TABLE = 'products';
  static const String PURCHASES_TABLE = 'purchases';
  static const String PURCHASE_ITEMS_TABLE = 'purchase_items';

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    _database = await DatabaseHelper().initDatabase();
    return _database!;
  }

  initDatabase() async {
    String path = join(await getDatabasesPath(), DB_NAME);
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $PERSONAL_TRANSACTIONS_TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        category TEXT,
        amount REAL,
        date TEXT,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $PRODUCTS_TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        initial_quantity INTEGER,
        price REAL,
        barcode TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $SALES_TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        buyer_name TEXT,
        sale_date TEXT
      )
    ''');
     await db.execute('''
      CREATE TABLE $SALE_ITEMS_TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        price REAL,
        FOREIGN KEY (sale_id) REFERENCES $SALES_TABLE(id),
        FOREIGN KEY (product_id) REFERENCES $PRODUCTS_TABLE(id)
      )
    ''');
     await db.execute('''
      CREATE TABLE $PURCHASES_TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_date TEXT,
        supplier TEXT,
        total_amount REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE $PURCHASE_ITEMS_TABLE (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        price REAL,
        FOREIGN KEY (purchase_id) REFERENCES $PURCHASES_TABLE(id),
        FOREIGN KEY (product_id) REFERENCES $PRODUCTS_TABLE(id)
      )
    ''');
  }

  Future<Map<String, List<Map<String, dynamic>>>> getSalesByBuyer() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> salesData = await db.rawQuery('''
      SELECT
        s.id AS sale_id,
        s.buyer_name,
        s.sale_date,
        si.quantity,
        si.price AS item_price,
        p.name AS product_name
      FROM $SALES_TABLE s
      JOIN $SALE_ITEMS_TABLE si ON s.id = si.sale_id
      JOIN $PRODUCTS_TABLE p ON si.product_id = p.id
      ORDER BY s.buyer_name, s.sale_date
    ''');

    final Map<String, List<Map<String, dynamic>>> groupedSales = {};
    for (var saleItem in salesData) {
      final buyerName = saleItem['buyer_name'] as String;
      if (!groupedSales.containsKey(buyerName)) {
        groupedSales[buyerName] = [];
      }
      groupedSales[buyerName]!.add(saleItem);
    }
    return groupedSales;
  }
}