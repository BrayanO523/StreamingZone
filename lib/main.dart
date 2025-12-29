import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'image_selector_dialog.dart';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es', null);
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
  DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.promo = false,
    this.category = 'Video',
    this.available = true,
    this.createdAt,
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
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// --- COMBO MODEL ---
class Combo {
  String id;
  String name;
  String description;
  double price;
  List<String> productIds; // IDs of products in the combo
  String imageUrl;
  bool available;

  Combo({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.productIds,
    this.imageUrl = '',
    this.available = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'productIds': productIds,
      'imageUrl': imageUrl,
      'available': available,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Combo.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Combo(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      productIds: List<String>.from(data['productIds'] ?? []),
      imageUrl: data['imageUrl'] ?? '',
      available: data['available'] ?? true,
    );
  }
}

// --- COMBOS VIEW ---
class CombosView extends StatelessWidget {
  const CombosView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('combos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No hay combos creados.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final combo = Combo.fromDocument(docs[index]);
            return Card(
              color: const Color(0xFF1e293b),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: combo.imageUrl.isNotEmpty
                    ? Image.network(
                        combo.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.layers, color: Colors.white54),
                      )
                    : const Icon(Icons.layers, color: Colors.white54),
                title: Text(
                  combo.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'HNL ${combo.price.toStringAsFixed(2)} • ${combo.productIds.length} productos',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: combo.available,
                      onChanged: (val) {
                        FirebaseFirestore.instance
                            .collection('combos')
                            .doc(combo.id)
                            .update({'available': val});
                      },
                      activeColor: const Color(0xFF6366f1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ComboDialog(combo: combo),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, combo),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Combo combo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e293b),
        title: const Text(
          'Eliminar Combo',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Seguro que quieres eliminar "${combo.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('combos')
                  .doc(combo.id)
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

// --- COMBO DIALOG ---
class ComboDialog extends StatefulWidget {
  final Combo? combo;

  const ComboDialog({super.key, this.combo});

  @override
  State<ComboDialog> createState() => _ComboDialogState();
}

class _ComboDialogState extends State<ComboDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  // Image logic
  Uint8List? _imageBytes;
  String? _imageFileName;
  // File? _imageFile; // Removed for web compatibility
  // final ImagePicker _picker = ImagePicker(); // Removed
  String? _currentImageUrl;
  bool _isUploading = false;

  List<String> _selectedProductIds = [];
  List<Product> _allProducts = []; // Full list
  List<Product> _filteredProducts = []; // Filtered List

  // Filter logic
  String _searchQuery = '';
  String _selectedCategory = 'Todas';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (widget.combo != null) {
      _nameController.text = widget.combo!.name;
      _descController.text = widget.combo!.description;
      _priceController.text = widget.combo!.price.toString();
      _currentImageUrl = widget.combo!.imageUrl;
      _selectedProductIds = List.from(widget.combo!.productIds);
    }
  }

  Future<void> _loadProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .get();
    setState(() {
      _allProducts = snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList();
      _filterProducts();
    });
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesSearch = p.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final matchesCategory =
            _selectedCategory == 'Todas' || p.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _pickImage() async {
    final result = await showDialog(
      context: context,
      builder: (context) =>
          ImageSelectorDialog(initialUrl: _currentImageUrl ?? ''),
    );

    if (result != null) {
      if (result['type'] == 'url') {
        setState(() {
          _currentImageUrl = result['data'];
          _imageBytes = null;
          _imageFileName = null;
        });
      } else if (result['type'] == 'bytes') {
        setState(() {
          _imageBytes = result['data'];
          _imageFileName = result['name'];
          // Keep current image url until upload is done or verified,
          // but strictly we'll show the bytes in preview.
        });
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return _currentImageUrl;
    try {
      final String fileName =
          _imageFileName ??
          'combos/${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Ensure path is combos/
      final String path = 'combos/${fileName.split('/').last}';

      final Reference ref = FirebaseStorage.instance.ref().child(path);
      // Upload bytes
      final UploadTask uploadTask = ref.putData(
        _imageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1e293b),
      title: Text(
        widget.combo == null ? 'Nuevo Combo' : 'Editar Combo',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_nameController, 'Nombre del Combo'),
                const SizedBox(height: 10),
                _buildTextField(_descController, 'Descripción', maxLines: 2),
                const SizedBox(height: 10),
                _buildTextField(
                  _priceController,
                  'Precio Total (HNL)',
                  isNumber: true,
                ),
                const SizedBox(height: 15),

                // Image Picker
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                      image: _imageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : (_currentImageUrl != null &&
                                _currentImageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(_currentImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        (_imageBytes == null &&
                            (_currentImageUrl == null ||
                                _currentImageUrl!.isEmpty))
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tocar para seleccionar imagen',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.white24),
                const SizedBox(height: 10),

                // --- Product Selection Header ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Seleccionar Productos:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Search Bar
                TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _filterProducts();
                  },
                ),
                const SizedBox(height: 10),

                // Category Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['Todas', 'Video', 'Música', 'Juegos', 'VPN', 'IA'].map(
                          (cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() {
                                    _selectedCategory = cat;
                                    _filterProducts();
                                  });
                                },
                                backgroundColor: Colors.white10,
                                selectedColor: const Color(0xFF6366f1),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            );
                          },
                        ).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // Product List
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _allProducts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            "No hay productos",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final isSelected = _selectedProductIds.contains(
                              product.id,
                            );
                            return CheckboxListTile(
                              title: Text(
                                product.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'HNL \${product.price}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              value: isSelected,
                              activeColor: const Color(0xFF6366f1),
                              checkColor: Colors.white,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProductIds.add(product.id);
                                  } else {
                                    _selectedProductIds.remove(product.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                if (_selectedProductIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${_selectedProductIds.length} productos seleccionados',
                      style: const TextStyle(color: Color(0xFF6366f1)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366f1),
          ),
          onPressed: _isUploading ? null : _saveCombo,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF6366f1)),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.black26,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          if (label == 'URL de Imagen (Opcional)')
            return null; // Logic handled by image picker now
          return 'Campo requerido';
        }
        return null;
      },
    );
  }

  Future<void> _saveCombo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un producto')),
      );
      return;
    }

    setState(() => _isUploading = true);

    final imageUrl = await _uploadImage();

    final comboData = {
      'name': _nameController.text,
      'description': _descController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'imageUrl': imageUrl ?? '',
      'productIds': _selectedProductIds,
      'available': true, // Default to true on create/edit
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.combo == null) {
        comboData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('combos').add(comboData);
      } else {
        await FirebaseFirestore.instance
            .collection('combos')
            .doc(widget.combo!.id)
            .update(comboData);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isUploading = false);
      }
    }
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const StatsView(),
    const FinancesView(),
    const InventoryView(),
    const CombosView(), // New View
    const OrdersView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StreamZone Admin'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign), // Megaphone for announcements
            onPressed: () => _showBannerConfig(context),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF6366f1),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1e293b),
        type: BottomNavigationBarType.fixed, // Needed for >3 items
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Finanzas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Inventario'),
          BottomNavigationBarItem(icon: Icon(Icons.layers), label: 'Combos'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Pedidos',
          ),
        ],
      ),
      floatingActionButton: _getFab(),
    );
  }

  Widget? _getFab() {
    if (_currentIndex == 2) {
      return FloatingActionButton(
        onPressed: () => _showProductDialog(context),
        child: const Icon(Icons.add),
      );
    } else if (_currentIndex == 3) {
      return FloatingActionButton(
        onPressed: () => _showComboDialog(context),
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (context) => ProductDialog(product: product),
    );
  }

  void _showComboDialog(BuildContext context, {Combo? combo}) {
    showDialog(
      context: context,
      builder: (context) => ComboDialog(combo: combo),
    );
  }

  void _showBannerConfig(BuildContext context) {
    showDialog(context: context, builder: (context) => const BannerDialog());
  }
}

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Todas';
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Búsqueda
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
          ),
        ),

        // Categorías (Diseño horizontal)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['Todas', 'Video', 'Música', 'Juegos', 'VPN', 'IA'].map((
              cat,
            ) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                  backgroundColor: Colors.white10,
                  selectedColor: Colors.blueAccent.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blueAccent : Colors.white70,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.requireData.docs;

              // Filtrado Local
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final desc = (data['description'] ?? '')
                    .toString()
                    .toLowerCase();
                final category = data['category'] ?? 'Video';

                bool matchesSearch =
                    name.contains(_searchText) || desc.contains(_searchText);
                bool matchesCategory =
                    _selectedCategory == 'Todas' ||
                    category == _selectedCategory;

                return matchesSearch && matchesCategory;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text(
                    'No se encontraron productos.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final product = Product.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  );
                  return ProductCard(product: product);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Resumen del Negocio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Products Count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final docs = snapshot.data!.docs;
              final total = docs.length;
              final unavailable = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data['available'] ?? true) == false;
              }).length;

              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Productos Totales',
                      value: total.toString(),
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Agotados',
                      value: unavailable.toString(),
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Orders Count
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final totalOrders = snapshot.data!.size;
              return _StatCard(
                title: 'Pedidos Recibidos',
                value: totalOrders.toString(),
                color: Colors.green,
              );
            },
          ),
          const SizedBox(height: 30),
          const Text(
            'Accesos Directos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: const Icon(Icons.star, color: Colors.yellow),
            title: const Text('Ver Opiniones (Web)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final url = Uri.parse(
                'https://streaming-plat-49327.web.app/opiniones.html',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  int _currentPage = 0;
  static const int _perPage = 30;
  final List<DocumentSnapshot> _checkpoints = [];

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(_perPage);

    // Apply cursor if not on first page
    if (_currentPage > 0 && _checkpoints.length >= _currentPage) {
      query = query.startAfterDocument(_checkpoints[_currentPage - 1]);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (_currentPage == 0) {
            return const Center(
              child: Text(
                'No hay pedidos registrados',
                style: TextStyle(color: Colors.grey),
              ),
            );
          } else {
            // Handle case where next page is empty (shouldn't happen with disabled button, but safe fallback)
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No hay más pedidos.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(onPressed: _prevPage, child: const Text("Volver")),
                ],
              ),
            );
          }
        }

        final docs = snapshot.data!.docs;
        final isLastPage = docs.length < _perPage;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final items = (data['items'] as List<dynamic>?) ?? [];
                  final total = data['total'] ?? 0.0;
                  final date = (data['createdAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white10,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrderDetailPage(data: data, orderId: doc.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.shopping_bag,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['customerName'] ?? 'Cliente',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'HNL ${total.toStringAsFixed(2)} • ${items.length} items',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    date != null
                                        ? DateFormat(
                                            'dd MMM, hh:mm a',
                                          ).format(date)
                                        : '',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _StatusBadge(status: data['status'] ?? 'pending'),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Pagination Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _currentPage > 0 ? _prevPage : null,
                  ),
                  Text('Página ${_currentPage + 1}'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    // If we have less than _perPage, we are at the end.
                    // IMPORTANT: We need snapshot data here to know if we can go next.
                    // But we are inside the builder, so we have 'docs'.
                    onPressed: !isLastPage ? () => _nextPage(docs.last) : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _nextPage(DocumentSnapshot lastDoc) {
    if (_checkpoints.length == _currentPage) {
      _checkpoints.add(lastDoc);
    } else {
      // Should match
      _checkpoints[_currentPage] = lastDoc;
    }
    setState(() {
      _currentPage++;
    });
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }
}

class FinancesView extends StatelessWidget {
  const FinancesView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Calculate Total Revenue (only completed orders)
        double totalRevenue = 0;
        final now = DateTime.now();
        final List<double> weeklyData = List.filled(7, 0.0);

        // Map weekdays: (DateTime.weekday) 1=Mon .. 7=Sun
        // We want today to be the last bar.

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'completed') {
            final price = (data['total'] ?? 0.0).toDouble();
            totalRevenue += price;

            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null) {
              final diff = now.difference(createdAt).inDays;
              if (diff < 7 && diff >= 0) {
                // diff 0 = today (index 6)
                // diff 6 = 7 days ago (index 0)
                final index = 6 - diff;
                if (index >= 0 && index < 7) {
                  weeklyData[index] += price;
                }
              }
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatCard(
                title: 'Ingresos Totales (Completados)',
                value: 'HNL ${NumberFormat("#,##0.00").format(totalRevenue)}',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 30),
              const Text(
                "Ingresos: Últimos 7 Días",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= 7)
                              return const SizedBox.shrink();
                            // Calculate label day
                            // index 6 is today, index 0 is 6 days ago
                            final day = now.subtract(Duration(days: 6 - index));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E', 'es').format(
                                  day,
                                ), // Needs intl initialization or simple switch
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyData.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value,
                            color: const Color(0xFF6366f1),
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BannerDialog extends StatefulWidget {
  const BannerDialog({super.key});

  @override
  State<BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<BannerDialog> {
  final _textController = TextEditingController();
  bool _isActive = false;
  String _selectedColor = '#6366f1'; // Default Indigo

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('banner')
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _textController.text = data['text'] ?? '';
        _isActive = data['isActive'] ?? false;
        _selectedColor = data['color'] ?? '#6366f1';
      });
    }
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('config').doc('banner').set({
      'text': _textController.text,
      'isActive': _isActive,
      'color': _selectedColor,
    });
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Banner actualizado')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Anuncio Web'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Mostrar Banner'),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          TextField(
            controller: _textController,
            decoration: const InputDecoration(labelText: 'Texto del Anuncio'),
          ),
          const SizedBox(height: 20),
          const Text('Color de Fondo'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorBtn('#6366f1'), // Indigo
              _colorBtn('#ef4444'), // Red
              _colorBtn('#22c55e'), // Green
              _colorBtn('#eab308'), // Yellow
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  Widget _colorBtn(String color) {
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
          shape: BoxShape.circle,
          border: _selectedColor == color
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
      ),
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
                    'HNL ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFa855f7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (product.createdAt != null)
                    Text(
                      'Ingreso: ${product.createdAt!.day}/${product.createdAt!.month}/${product.createdAt!.year}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
  // late TextEditingController _imageController; // Removed in favor of file picker
  Uint8List? _imageBytes;
  String? _imageFileName;
  // File? _imageFile;
  // final ImagePicker _picker = ImagePicker();
  String? _currentImageUrl;
  bool _isUploading = false;

  bool _isPromo = false;
  bool _isAvailable = true;
  String _selectedCategory = 'Video';

  final List<String> _categories = [
    'Video',
    'Música',
    'Juegos',
    'VPN',
    'Software',
    'IA',
    'Seguidores',
    'Otro',
  ];

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
    _currentImageUrl = widget.product?.imageUrl;
    _isPromo = widget.product?.promo ?? false;
    _isAvailable = widget.product?.available ?? true;
    _selectedCategory = widget.product?.category ?? 'Video';
  }

  Future<void> _pickImage() async {
    final result = await showDialog(
      context: context,
      builder: (context) =>
          ImageSelectorDialog(initialUrl: _currentImageUrl ?? ''),
    );

    if (result != null) {
      if (result['type'] == 'url') {
        setState(() {
          _currentImageUrl = result['data'];
          _imageBytes = null;
        });
      } else if (result['type'] == 'bytes') {
        setState(() {
          _imageBytes = result['data'];
          _imageFileName = result['name'];
        });
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return _currentImageUrl;
    try {
      final String fileName =
          _imageFileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'products/${fileName.split('/').last}';

      final Reference ref = FirebaseStorage.instance.ref().child(path);

      final UploadTask uploadTask = ref.putData(
        _imageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      }
      return null;
    }
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
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[600]!),
                    image: _imageBytes != null
                        ? DecorationImage(
                            image: MemoryImage(_imageBytes!),
                            fit: BoxFit.cover,
                          )
                        : (_currentImageUrl != null &&
                              _currentImageUrl!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(_currentImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child:
                      (_imageBytes == null &&
                          (_currentImageUrl == null ||
                              _currentImageUrl!.isEmpty))
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey,
                            ),
                            Text(
                              'Tocar para seleccionar imagen',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : null,
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
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveProduct,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);
    final String? imageUrl = await _uploadImage();

    if (imageUrl == null && _imageBytes != null) {
      // Failed upload
      setState(() => _isUploading = false);
      return;
    }

    final data = {
      'name': _nameController.text,
      'description': _descController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'imageUrl': imageUrl ?? '',
      'promo': _isPromo,
      'category': _selectedCategory,
      'available': _isAvailable,
      if (widget.product == null) 'createdAt': FieldValue.serverTimestamp(),
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
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class OrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;

  const OrderDetailPage({super.key, required this.data, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List<dynamic>?) ?? [];
    final total = data['total'] ?? 0.0;
    final date = (data['createdAt'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'pending';
    final phone = data['phone'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Orden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              _copyOrderToClipboard(
                context,
                items,
                total,
                data['customerName'] ?? 'Cliente',
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orden #${orderId.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        date != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(date)
                            : '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const Divider(height: 32),

            // Customer
            const Text(
              'Cliente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                data['customerName'] ?? 'Sin Nombre',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(phone),
              trailing: IconButton(
                icon: const Icon(Icons.message, color: Colors.green),
                onPressed: () => _launchWhatsApp(phone),
              ),
            ),
            const Divider(height: 32),

            // Items
            const Text(
              'Productos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final imgUrl = item['imageUrl'] as String?;
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (imgUrl != null && imgUrl.isNotEmpty)
                            ? Image.network(
                                imgUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey,
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.blueGrey,
                                child: const Icon(Icons.shopping_bag),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? 'Producto',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Cant: ${item['qty'] ?? 1} x HNL ${item['price']}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'HNL ${(item['qty'] ?? 1) * (item['price'] ?? 0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total General:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'HNL ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const Divider(height: 40),

            // Actions
            const Text(
              'Gestionar Estado',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionBtn(
                  label: 'Pendiente',
                  color: Colors.orange,
                  icon: Icons.schedule,
                  onTap: () => _updateStatus(context, 'pending'),
                ),
                _ActionBtn(
                  label: 'Completar',
                  color: Colors.green,
                  icon: Icons.check_circle,
                  onTap: () => _updateStatus(context, 'completed'),
                ),
                _ActionBtn(
                  label: 'Cancelar',
                  color: Colors.red,
                  icon: Icons.cancel,
                  onTap: () => _updateStatus(context, 'cancelled'),
                ),
                _ActionBtn(
                  label: 'Archivar',
                  color: Colors.grey,
                  icon: Icons.archive,
                  onTap: () => _updateStatus(context, 'archived'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _launchWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    // Remove +504 if double
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('504') && cleanPhone.length == 8)
      cleanPhone = '504$cleanPhone';

    final url = Uri.parse("https://wa.me/$cleanPhone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _copyOrderToClipboard(
    BuildContext context,
    List items,
    dynamic total,
    String name,
  ) {
    String text = "*Pedido de $name:*\n";
    for (var item in items) {
      text += "- ${item['qty']}x ${item['name']}\n";
    }
    text += "*Total: HNL $total*";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido copiado al portapapeles')),
    );
  }

  void _updateStatus(BuildContext context, String newStatus) {
    FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
    Navigator.pop(context); // Go back after update
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'archived':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
