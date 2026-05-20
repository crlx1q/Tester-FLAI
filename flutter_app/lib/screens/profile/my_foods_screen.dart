import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/api_helper.dart';
import '../../utils/image_helper.dart';
import '../../models/food_model.dart';

class MyFoodsScreen extends StatefulWidget {
  const MyFoodsScreen({super.key});

  @override
  State<MyFoodsScreen> createState() => _MyFoodsScreenState();
}

class _MyFoodsScreenState extends State<MyFoodsScreen> {
  List<FoodModel> _foods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() => _isLoading = true);

    final result = await ApiHelper.getFoodHistory();

    if (result['success']) {
      setState(() {
        _foods = (result['foods'] as List)
            .map((f) => FoodModel.fromJson(f))
            .toList();
      });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои блюда'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _foods.isEmpty
              ? const Center(
                  child: Text('У вас пока нет записей о блюдах'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _foods.length,
                  itemBuilder: (context, index) {
                    final food = _foods[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: food.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ImageHelper.buildImage(
                                    food.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: const Icon(Icons.restaurant),
                                  ),
                                )
                              : const Icon(Icons.restaurant, size: 30),
                        ),
                        title: Text(
                          food.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm')
                                  .format(food.timestamp),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Б: ${food.macros.protein}г  Ж: ${food.macros.fat}г  У: ${food.macros.carbs}г',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${food.calories} ккал',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
