import 'package:flutter/material.dart';
import 'package:slowpizza_web/screens/mesas_screen.dart';
import '../widgets/menu_tile.dart';
import '../theme/app_colors.dart';
import '../screens/pizzas_screen.dart';
import '../screens/painel_pedidos_screen.dart';
import '../screens/pedidos_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/financeiro_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Número de colunas se ajusta ao tamanho da tela
    final crossAxisCount = width > 600 ? 2 : 1;

    // Ajusta a proporção para evitar tiles muito altos em telas pequenas
    final childAspectRatio = width > 600 ? 1.2 : 2.8;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Admin"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),

        // 🔥 IMPORTANTE: Usa GridView.builder para garantir scroll correto
        child: GridView.builder(
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final items = [
              MenuTile(
                icon: Icons.local_pizza,
                label: "Pizzas",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PizzasScreen()),
                ),
              ),
              MenuTile(
                icon: Icons.shopping_cart,
                label: "Painel Pedidos",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PainelPedidosScreen()),
                ),
              ),
              MenuTile(
                icon: Icons.shopping_cart,
                label: "Fazer Pedidos",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PedidosScreen()),
                ),
              ),
              MenuTile(
                icon: Icons.people,
                label: "Clientes",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClientesScreen()),
                ),
              ),
              MenuTile(
                icon: Icons.attach_money,
                label: "Financeiro",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinanceiroScreen()),
                ),
              ),
              MenuTile(
                icon: Icons.table_restaurant,
                label: "Mesas",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MesasScreen()),
                ),
              ),
            ];

            return items[index];
          },
        ),
      ),
    );
  }
}
