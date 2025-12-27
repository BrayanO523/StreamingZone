import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StreamZone Admin',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF6366f1),
        scaffoldBackgroundColor: const Color(0xFF0f172a),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1e293b),
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6366f1),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366f1),
          secondary: Color(0xFFa855f7),
          surface: Color(0xFF1e293b),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class Product {
  String id;
  String name;
  String description;
  double price;
  String imageUrl;
  bool promo;
  String category;
  bool available;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.promo = false,
    this.category = 'Video',
    this.available = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'promo': promo,
      'category': category,
      'available': available,
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      promo: map['promo'] ?? false,
      category: map['category'] ?? 'Video',
      available: map['available'] ?? true,
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StreamZone Admin'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.requireData;

          if (data.size == 0) {
            return const Center(
              child: Text(
                'No hay servicios registrados.\nAgrega uno con el botón (+)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.size,
            itemBuilder: (context, index) {
              final doc = data.docs[index];
              final product = Product.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              );
              return ProductCard(product: product);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (context) => ProductDialog(product: product),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: product.available ? null : Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black26,
                image: product.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl),
                        fit: BoxFit.cover,
                        colorFilter: product.available
                            ? null
                            : const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.saturation,
                              ),
                      )
                    : null,
              ),
              child: product.imageUrl.isEmpty
                  ? const Icon(Icons.image_not_supported, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!product.available)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AGOTADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            decoration: product.available
                                ? null
                                : TextDecoration.lineThrough,
                            color: product.available ? null : Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.promo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.pink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OFERTA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFa855f7),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ProductDialog(product: product),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context, product),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${product.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('products')
                  .doc(product.id)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ProductDialog extends StatefulWidget {
  final Product? product;

  const ProductDialog({super.key, this.product});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _imageController;
  bool _isPromo = false;
  bool _isAvailable = true;
  String _selectedCategory = 'Video';

  final List<String> _categories = ['Video', 'Música', 'Juegos', 'VPN', 'Otro'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _imageController = TextEditingController(
      text: widget.product?.imageUrl ?? '',
    );
    _isPromo = widget.product?.promo ?? false;
    _isAvailable = widget.product?.available ?? true;
    _selectedCategory = widget.product?.category ?? 'Video';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Nuevo Servicio' : 'Editar Servicio',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Servicio',
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v!) == null ? 'Inválido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'URL de Imagen',
                  hintText: 'https://...',
                  suffixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Disponible (Stock)'),
                value: _isAvailable,
                subtitle: Text(
                  _isAvailable
                      ? 'Visible para clientes'
                      : 'Marcado como AGOTADO',
                ),
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              SwitchListTile(
                title: const Text('En Oferta'),
                value: _isPromo,
                onChanged: (v) => setState(() => _isPromo = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _saveProduct, child: const Text('Guardar')),
      ],
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text,
      'description': _descController.text,
      'price': double.parse(_priceController.text),
      'imageUrl': _imageController.text,
      'promo': _isPromo,
      'category': _selectedCategory,
      'available': _isAvailable,
    };

    try {
      if (widget.product == null) {
        await FirebaseFirestore.instance.collection('products').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id)
            .update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
