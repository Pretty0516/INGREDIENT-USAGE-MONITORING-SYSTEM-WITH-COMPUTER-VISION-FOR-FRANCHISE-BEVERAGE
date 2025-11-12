// for standardization navigation bar and the top bar for user information and notification
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart';
import '../providers/auth_provider.dart';

class AppShell extends StatefulWidget {
  final Widget body;
  final String activeItem; // e.g., 'Staff', 'Product', etc.

  const AppShell({
    super.key,
    required this.body,
    this.activeItem = 'Staff',
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isSideNavOpen = true;

  @override
  Widget build(BuildContext context) {
    final isLaptop = MediaQuery.of(context).size.width >= 1024;
    final authProvider = context.watch<AuthProvider>();
    final currentUserModel = authProvider.currentUser;
    // for top bar and the notification icon
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (isLaptop)
                  IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Toggle navigation',
                    onPressed: () => setState(() => _isSideNavOpen = !_isSideNavOpen),
                  ),
                if (isLaptop) const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.green[100],
                  child: Text(
                    _initials(currentUserModel?.firstName, currentUserModel?.lastName),
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentUserModel?.fullName ?? 'User',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Logged in since: ${_formatLoginTime(currentUserModel?.lastLoginAt)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifications coming soon')),
                        );
                      },
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Text(' ', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // for the navigation bar
      body: SafeArea(
        top: false, // prevent extra top padding under app bar
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = widget.body;
            if (constraints.maxWidth >= 1024) {
              // Overlay the sidebar so content position doesn't shift when toggled
              return Stack(
                children: [
                  Positioned.fill(child: content),
                  if (_isSideNavOpen)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _buildSideNav(),
                    ),
                ],
              );
            }
            return content;
          },
        ),
      ),
      bottomNavigationBar: isLaptop ? null : _buildBottomNav(),
    );
  }
  // bottom navigation bar for tablet and mobile
  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.orange[50],
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(Icons.list_alt, 'Order List', onTap: () {}),
            _navItem(Icons.people, 'Staff', active: widget.activeItem == 'Staff', onTap: _goToStaff),
          _navItem(Icons.local_offer, 'Product', active: widget.activeItem == 'Product', onTap: _goToProduct),
          _navItem(Icons.kitchen, 'Ingredient', active: widget.activeItem == 'Ingredient', onTap: _goToIngredient),
            _navItem(Icons.inventory_2, 'Inventory', active: widget.activeItem == 'Inventory', onTap: () {}),
            _navItem(Icons.health_and_safety, 'Hygiene', active: widget.activeItem == 'Hygiene', onTap: () {}),
            _navItem(Icons.bar_chart, 'Report', active: widget.activeItem == 'Report', onTap: () {}),
          ],
        ),
      ),
    );
  }

  // bottom navigation bar item
  Widget _navItem(IconData icon, String label, {bool active = false, required VoidCallback onTap}) {
    final color = active ? Colors.orange[700] : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // side navigation bar for website
  Widget _buildSideNav() {
    return Container(
      width: 180,
      color: Colors.orange[50],
      child: Column(
        children: [
          const SizedBox(height: 12),
          _sideNavItem(Icons.list_alt, 'Order List', active: widget.activeItem == 'Order List', onTap: () {}),
          _sideNavItem(Icons.people, 'Staff', active: widget.activeItem == 'Staff', onTap: _goToStaff),
          _sideNavItem(Icons.local_offer, 'Product', active: widget.activeItem == 'Product', onTap: _goToProduct),
          _sideNavItem(Icons.kitchen, 'Ingredient', active: widget.activeItem == 'Ingredient', onTap: _goToIngredient),
          _sideNavItem(Icons.inventory_2, 'Inventory', active: widget.activeItem == 'Inventory', onTap: () {}),
          _sideNavItem(Icons.health_and_safety, 'Hygiene', active: widget.activeItem == 'Hygiene', onTap: () {}),
          _sideNavItem(Icons.bar_chart, 'Report', active: widget.activeItem == 'Report', onTap: () {}),
        ],
      ),
    );
  }
  
  void _goToStaff() {
    final authProvider = context.read<AuthProvider>();
    final fid = authProvider.currentUser?.franchiseId;
    if (fid != null && fid.isNotEmpty) {
      context.go('${AppRoutes.staffManagement}?franchiseId=$fid');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Franchise information not available')),
      );
    }
  }

  void _goToProduct() {
    context.go(AppRoutes.productManagement);
  }

  void _goToIngredient() {
    context.go(AppRoutes.ingredientManagement);
  }

  // side navigation bar item
  Widget _sideNavItem(IconData icon, String label, {bool active = false, required VoidCallback onTap}) {
    final color = active ? (Colors.orange[700] ?? Colors.orange) : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: active ? (Colors.orange[700] ?? Colors.orange) : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
  // for initials of user name
  String _initials(String? firstName, String? lastName) {
    final f = (firstName ?? '').trim();
    final l = (lastName ?? '').trim();
    String i1 = f.isNotEmpty ? f[0] : '';
    String i2 = l.isNotEmpty ? l[0] : '';
    return (i1 + i2).toUpperCase();
  }

  // for login time format
  String _formatLoginTime(DateTime? dt) {
    if (dt == null) return '-';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'pm' : 'am';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$day/$month/$year $hour:$minute $ampm';
  }
}