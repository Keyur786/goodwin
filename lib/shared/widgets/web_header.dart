import 'package:flutter/material.dart';
import 'package:goodwin/core/state/notification_controller.dart';
import 'package:goodwin/models/user_model.dart';
import 'package:goodwin/shared/widgets/profile_avatar_widget.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class WebHeader extends StatelessWidget implements PreferredSizeWidget {
  const WebHeader({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.searchController,
    required this.onSearchChanged,
    required this.cartItemCount,
    required this.cartTotalAmount,
    required this.favoriteCount,
    this.currentUser,
    required this.isAdmin,
    required this.onOpenPickupModal,
    required this.onOpenNotifications,
    required this.onOpenBulkQuotes,
    required this.onOpenAdminDashboard,
    required this.onOpenAdminProducts,
    required this.onOpenAdminOrders,
    required this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final int cartItemCount;
  final double cartTotalAmount;
  final int favoriteCount;
  final AppUser? currentUser;
  final bool isAdmin;
  final VoidCallback onOpenPickupModal;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenBulkQuotes;
  final VoidCallback onOpenAdminDashboard;
  final VoidCallback onOpenAdminProducts;
  final VoidCallback onOpenAdminOrders;
  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Row(
            children: [
              // 1. Logo & Brand
              InkWell(
                onTap: () => onSelectTab(0),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.store,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GOODWIN',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF0F172A),
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'WHOLESALE B2B',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // 2. Global Search Bar (E-commerce Style)
              Expanded(
                flex: 3,
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search wholesale catalog, SKU, categories...',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // 3. Navigation Links (Home, Catalog, Favorites, Bulk Quotes)
              _HeaderNavLink(
                label: 'Home',
                icon: LucideIcons.house,
                isSelected: selectedIndex == 0,
                onTap: () => onSelectTab(0),
              ),
              _HeaderNavLink(
                label: 'Catalog',
                icon: LucideIcons.layoutGrid,
                isSelected: selectedIndex == 1,
                onTap: () => onSelectTab(1),
              ),
              _HeaderNavLink(
                label: 'Favorites',
                icon: LucideIcons.heart,
                isSelected: selectedIndex == 2,
                badgeCount: favoriteCount,
                onTap: () => onSelectTab(2),
              ),
              _HeaderNavLink(
                label: 'Bulk Quotes',
                icon: LucideIcons.messageSquare,
                isSelected: false,
                onTap: onOpenBulkQuotes,
              ),

              const SizedBox(width: 12),
              const SizedBox(
                height: 28,
                child: VerticalDivider(color: Color(0xFFE2E8F0), width: 1),
              ),
              const SizedBox(width: 12),

              // 4. Warehouse Pickup Button
              OutlinedButton.icon(
                onPressed: onOpenPickupModal,
                icon: const Icon(LucideIcons.mapPin, size: 15, color: Color(0xFF2563EB)),
                label: const Text(
                  'Katargam Hub',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  backgroundColor: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(width: 10),

              // 5. Notifications Bell
              ListenableBuilder(
                listenable: NotificationController(),
                builder: (context, _) {
                  final unread = NotificationController().unreadCount;
                  return IconButton(
                    tooltip: 'Notifications',
                    onPressed: onOpenNotifications,
                    icon: unread > 0
                        ? Badge.count(
                            count: unread,
                            backgroundColor: const Color(0xFFDC2626),
                            child: const Icon(LucideIcons.bell, size: 20, color: Color(0xFF334155)),
                          )
                        : const Icon(LucideIcons.bell, size: 20, color: Color(0xFF334155)),
                  );
                },
              ),

              const SizedBox(width: 8),

              // 6. Cart Button with Amount Pill
              FilledButton.icon(
                onPressed: () => onSelectTab(3),
                icon: cartItemCount > 0
                    ? Badge.count(
                        count: cartItemCount,
                        backgroundColor: Colors.white,
                        textColor: const Color(0xFF2563EB),
                        child: const Icon(LucideIcons.shoppingBag, size: 18),
                      )
                    : const Icon(LucideIcons.shoppingBag, size: 18),
                label: Text(
                  cartTotalAmount > 0
                      ? '₹${cartTotalAmount.toStringAsFixed(0)}'
                      : 'Cart',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(width: 14),

              // 7. Admin Tools / User Profile Menu
              PopupMenuButton<String>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ProfileAvatarWidget(
                        radius: 14,
                        photoUrl: currentUser?.photoUrl,
                        name: currentUser?.name ?? (isAdmin ? 'Admin' : 'User'),
                        showCameraBadge: false,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentUser?.name.isNotEmpty == true
                            ? currentUser!.name
                            : (isAdmin ? 'Goodwin Admin' : 'Reseller'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  if (isAdmin) ...[
                    const PopupMenuItem(
                      enabled: false,
                      child: Text(
                        'ADMIN MANAGEMENT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'admin_dashboard',
                      onTap: onOpenAdminDashboard,
                      child: const Row(
                        children: [
                          Icon(LucideIcons.layoutDashboard, size: 17, color: Color(0xFF475569)),
                          SizedBox(width: 10),
                          Text('Admin Dashboard'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'admin_products',
                      onTap: onOpenAdminProducts,
                      child: const Row(
                        children: [
                          Icon(LucideIcons.packagePlus, size: 17, color: Color(0xFF475569)),
                          SizedBox(width: 10),
                          Text('Manage Products'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'admin_orders',
                      onTap: onOpenAdminOrders,
                      child: const Row(
                        children: [
                          Icon(LucideIcons.clipboardList, size: 17, color: Color(0xFF475569)),
                          SizedBox(width: 10),
                          Text('Customer Orders'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  PopupMenuItem(
                    value: 'pickup',
                    onTap: onOpenPickupModal,
                    child: const Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 17, color: Color(0xFF475569)),
                        SizedBox(width: 10),
                        Text('Pickup Location (Katargam)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sign_out',
                    onTap: onLogout,
                    child: const Row(
                      children: [
                        Icon(LucideIcons.logOut, size: 17, color: Color(0xFFDC2626)),
                        SizedBox(width: 10),
                        Text('Sign Out', style: TextStyle(color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderNavLink extends StatefulWidget {
  const _HeaderNavLink({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  State<_HeaderNavLink> createState() => _HeaderNavLinkState();
}

class _HeaderNavLinkState extends State<_HeaderNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.badgeCount != null && widget.badgeCount! > 0)
                Badge.count(
                  count: widget.badgeCount!,
                  backgroundColor: const Color(0xFF2563EB),
                  child: Icon(
                    widget.icon,
                    size: 17,
                    color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                )
              else
                Icon(
                  widget.icon,
                  size: 17,
                  color: active ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: active ? const Color(0xFF2563EB) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
