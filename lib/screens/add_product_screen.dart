import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode and DiagnosticPropertiesBuilder
import 'package:sqflite/sqflite.dart';
import 'package:barcode/barcode.dart' as bc_library;
import 'package:image/image.dart' as img;
import 'package:barcode_image/barcode_image.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart'; // This now correctly imports the version you have
import 'package:myapp/services/database_helper.dart'; // Assuming this path is correct
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final TextEditingController _productNameController =
      TextEditingController();
  final TextEditingController _initialQuantityController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Uint8List? _barcodePngBytes;

  @override
  void initState() {
    super.initState();
    _barcodeController.addListener(_handleBarcodeTextChange);
  }

  void _handleBarcodeTextChange() {
    _generateAndSetBarcodeImage(_barcodeController.text);
  }

  Future<void> _generateAndSetBarcodeImage(String textData) async {
    if (textData.isEmpty) {
      if (mounted) {
        setState(() {
          _barcodePngBytes = null;
        });
      }
      return;
    }

    try {
      final barcode = bc_library.Barcode.code128();
      const int imageWidth = 300;
      const int imageHeight = 100;

      final image = img.Image(width: imageWidth, height: imageHeight);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      drawBarcode(
        image,
        barcode,
        textData,
        font: img.arial14,
        x: 5,
        y: 5,
        width: imageWidth - 10,
        height: imageHeight - 20,
      );

      final pngBytes = Uint8List.fromList(img.encodePng(image));
      if (mounted) {
        setState(() {
          _barcodePngBytes = pngBytes;
        });
      }
    } catch (e) {
      debugPrint('Error generating barcode image: $e');
      if (mounted) {
        setState(() {
          _barcodePngBytes = null;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating barcode: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_handleBarcodeTextChange);
    _productNameController.dispose();
    _initialQuantityController.dispose();
    _priceController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      Database database = await DatabaseHelper.getDatabase();
      Map<String, dynamic> product = {
        'name': _productNameController.text,
        'initial_quantity':
            int.tryParse(_initialQuantityController.text) ?? 0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'barcode': _barcodeController.text,
      };
      int id = await database.insert('products', product);
      debugPrint('Product saved with ID: $id');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _shareBarcode() async {
    if (_barcodePngBytes == null || _barcodePngBytes!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No barcode image to share.')),
      );
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final imgFile = File('${directory.path}/barcode.png');
      await imgFile.writeAsBytes(_barcodePngBytes!);

      // Corrected sharing call based on the provided share_plus API
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(imgFile.path)],
          text: 'Product Barcode: ${_barcodeController.text}',
          // subject: 'Product Barcode', // Optional: if you want a subject for email
        ),
      );

      // Optionally, handle the result
      if (result.status == ShareResultStatus.success) {
        debugPrint('Barcode shared successfully!');
      } else if (result.status == ShareResultStatus.dismissed) {
        debugPrint('Share sheet was dismissed.');
      } else if (result.status == ShareResultStatus.unavailable) {
        debugPrint('Sharing is unavailable.');
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing is not available on this device/platform.')),
          );
        }
      }
      // Log raw value for any other cases
      debugPrint('Share result: ${result.status}, raw: ${result.raw}');


    } catch (e) {
      debugPrint('Error sharing barcode: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing barcode: ${e.toString()}')),
      );
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _initialQuantityController,
                decoration: const InputDecoration(
                  labelText: 'Initial Quantity',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter initial quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        contentPadding: EdgeInsets.symmetric(vertical: 15.0),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a barcode';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  ElevatedButton(
                    onPressed: () {
                      _barcodeController.text =
                          'SAMPLE${Random().nextInt(100000000)}';
                    },
                    child: const Text('Generate'),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              if (_barcodePngBytes != null)
                Center(
                  child: SizedBox(
                    height: 100,
                    child: Image.memory(
                      _barcodePngBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              const SizedBox(height: 24.0),
              if (_barcodePngBytes != null)
                ElevatedButton.icon(
                  onPressed: _shareBarcode,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Barcode'),
                ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _saveProduct,
                child: const Text('Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // Only add these in debug mode
    if (kDebugMode) {
      properties.add(DiagnosticsProperty<TextEditingController>(
          'productNameController', _productNameController));
      properties.add(DiagnosticsProperty<TextEditingController>(
          'initialQuantityController', _initialQuantityController));
      properties.add(DiagnosticsProperty<TextEditingController>(
          'priceController', _priceController));
      properties.add(DiagnosticsProperty<TextEditingController>(
          'barcodeController', _barcodeController));
      properties.add(DiagnosticsProperty<GlobalKey<FormState>>('formKey', _formKey));
      properties.add(DiagnosticsProperty<Uint8List>('_barcodePngBytes', _barcodePngBytes));
    }
  }
}