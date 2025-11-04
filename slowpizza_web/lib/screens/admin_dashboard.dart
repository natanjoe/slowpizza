import 'package:flutter/material.dart';
import '../widgets/menu_tile.dart';
import '../theme/app_colors.dart';
import '../screens/pizzas_screen.dart';
import '../screens/pedidos_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/financeiro_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Define número de colunas adaptativo
    int crossAxisCount = MediaQuery.of(context).size.width > 600 ? 2 : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Aqui você coloca a lógica de logout
              Navigator.pop(context); // exemplo simples
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          children: [
            MenuTile(
              icon: Icons.local_pizza,
              label: "Pizzas",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PizzasScreen()),
                );
              },
            ),
            MenuTile(
              icon: Icons.shopping_cart,
              label: "Pedidos",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PedidosScreen()),
                );
              },
            ),
            MenuTile(
              icon: Icons.people,
              label: "Clientes",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientesScreen()),
                );
              },
            ),
            MenuTile(
              icon: Icons.attach_money,
              label: "Financeiro",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinanceiroScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
