import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api/tasks_api.dart';
import '../models/task.dart';
import '../state/auth_state.dart';
import 'messages_page.dart';
import 'map_page.dart';
import 'create_task_page.dart';
import 'my_tasks_page.dart';
import 'task_detail_page.dart';
import '../widgets/auth_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Task>> futureTasks;
  final Set<int> _loadingActions = {};
  int _selectedCategoryIndex = 0;

  final List<_CategoryItem> _categories = const [
    _CategoryItem(label: 'Saptamana asta', icon: Icons.calendar_month_outlined),
    _CategoryItem(label: 'Pentru dvs', icon: Icons.star_outline),
    _CategoryItem(label: 'In tendinta', icon: Icons.trending_up),
    _CategoryItem(label: 'Arta', icon: Icons.brush_outlined),
    _CategoryItem(label: 'Interioare', icon: Icons.weekend_outlined),
    _CategoryItem(label: 'Bijuterii', icon: Icons.diamond_outlined),
    _CategoryItem(label: 'Ceasuri', icon: Icons.watch_later_outlined),
    _CategoryItem(label: 'Moda', icon: Icons.checkroom_outlined),
    _CategoryItem(label: 'Monede', icon: Icons.savings_outlined),
    _CategoryItem(label: 'Benzi desenate', icon: Icons.menu_book_outlined),
    _CategoryItem(label: 'Vehicule', icon: Icons.directions_car_filled_outlined),
  ];

  @override
  void initState() {
    super.initState();
    futureTasks = fetchTasks();
  }

  Future<void> _refresh() async {
    setState(() {
      futureTasks = fetchTasks();
    });
  }

  Widget _buildAuthAction(Color primaryBlue, {bool compact = false}) {
    final auth = AuthState.instance;

    String initials(String name) {
      final parts = name.trim().split(' ');
      if (parts.isEmpty) return '';
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
      return (first + last).toUpperCase();
    }

    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.isAuthenticated && auth.user != null) {
          final user = auth.user!;
          final avatar = CircleAvatar(
            radius: compact ? 16 : 18,
            backgroundColor: primaryBlue.withOpacity(0.12),
            child: Text(
              initials(user.name),
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          Widget buildMenuButton(Widget child) {
            return PopupMenuButton<String>(
              tooltip: 'Meniu cont',
              onSelected: (value) {
                switch (value) {
                  case 'create':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateTaskPage()),
                    );
                    break;
                  case 'tasks':
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyTasksPage()),
                    );
                    break;
                  case 'messages':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MessagesPage(),
                      ),
                    );
                    break;
                  case 'settings':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigare spre setari (TODO)')),
                    );
                    break;
                  case 'profile':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Navigare spre profil (TODO)')),
                    );
                    break;
                  case 'logout':
                    auth.logout();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create',
                  child: Text('Creeaza task'),
                ),
                const PopupMenuItem(
                  value: 'tasks',
                  child: Text('Task-urile mele'),
                ),
                const PopupMenuItem(
                  value: 'messages',
                  child: Text('Mesaje'),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Setari'),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('Profil'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Deconectare'),
                ),
              ],
              child: child,
            );
          }

          if (compact) {
            return buildMenuButton(avatar);
          }

          return buildMenuButton(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                const SizedBox(width: 8),
                Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          );
        }

        if (compact) {
          return IconButton(
            onPressed: () => showAuthDialog(context),
            icon: Icon(Icons.person_outline, color: primaryBlue),
          );
        }

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => showAuthDialog(context),
          child: const Text('Conectare'),
        );
      },
    );
  }

  Future<void> _handleAction({
    required Task task,
    required bool accept,
  }) async {
    final auth = AuthState.instance;
    if (!auth.isAuthenticated || auth.user == null) {
      await showAuthDialog(context);
      return;
    }
    setState(() {
      _loadingActions.add(task.id);
    });

    try {
      if (accept) {
        await acceptTaskApi(task.id, userId: auth.user!.id);
      } else {
        await refuseTaskApi(task.id, userId: auth.user!.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Task acceptat' : 'Task refuzat'),
          ),
        );
      }

      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A aparut o eroare: $e'),
          ),
        );
      }
    } finally {
      setState(() {
        _loadingActions.remove(task.id);
      });
    }
  }

  void _openTaskDetails(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailPage(task: task),
      ),
    );
  }

  void _showTaskOnMap(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (_) {
        return SizedBox(
          height: 320,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(task.lat, task.lng),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.taskul.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(task.lat, task.lng),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);

    final auth = AuthState.instance;

    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          body: SafeArea(
            child: RefreshIndicator(
              color: primaryBlue,
              onRefresh: _refresh,
              child: FutureBuilder<List<Task>>(
                future: futureTasks,
                builder: (context, snapshot) {
                  final tasks = snapshot.data ?? [];
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                  final heroTask = tasks.isNotEmpty ? tasks.first : null;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildTopNav(primaryBlue)),
                      SliverToBoxAdapter(child: _buildTrustStrip()),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _CategoryHeaderDelegate(
                          categories: _categories,
                          selectedIndex: _selectedCategoryIndex,
                          onTap: (index) {
                            setState(() => _selectedCategoryIndex = index);
                          },
                          primaryBlue: primaryBlue,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildHeroSection(
                          primaryBlue,
                          heroTask,
                          isLoading,
                          isAuthenticated: auth.isAuthenticated,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildCollectionStrip(primaryBlue),
                      ),
                      if (isLoading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        )
                      else if (tasks.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: Text('Nu exista task-uri de afisat momentan.'),
                            ),
                          ),
                        )
                      else
                        _buildGridSection(primaryBlue, tasks),
                      SliverToBoxAdapter(child: _buildFooter(primaryBlue, auth.isAuthenticated)),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopNav(Color primaryBlue) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;

          return Wrap(
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Logo(primaryBlue: primaryBlue),
                  const SizedBox(width: 16),
                  _NavPill(
                    icon: Icons.widgets_outlined,
                    label: 'Categorii',
                    trailing: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (!isCompact) const SizedBox(width: 16),
              if (isCompact)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.favorite_border, color: primaryBlue),
                    ),
                    _buildAuthAction(primaryBlue, compact: true),
                  ],
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 220,
                  maxWidth: isCompact ? constraints.maxWidth : 420,
                ),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cautati dupa marca, model, artist...',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      filled: true,
                      fillColor: const Color(0xFFF4F6FB),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDFE3EC)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryBlue),
                      ),
                    ),
                  ),
                ),
              ),
              if (!isCompact)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Cum functioneaza?'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Ajutor'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.favorite_border),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.language),
                    ),
                    const SizedBox(width: 12),
                    _buildAuthAction(primaryBlue),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrustStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Text(
            'Licitati saptamanal la cele peste 65,000+ de obiecte speciale, selectate de 240 experti',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.star, color: Colors.green, size: 18),
              Icon(Icons.star, color: Colors.green, size: 18),
              Icon(Icons.star, color: Colors.green, size: 18),
              Icon(Icons.star, color: Colors.green, size: 18),
              Icon(Icons.star_half, color: Colors.green, size: 18),
            ],
          ),
          const Text(
            '123.232 review-uri pe Trustpilot',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Color primaryBlue, Task? heroTask, bool isLoading,
      {required bool isAuthenticated}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;
          final image = (heroTask?.images.isNotEmpty ?? false)
              ? heroTask!.images.first
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) _buildHeroText(primaryBlue),
              if (isNarrow) const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isNarrow) ...[
                    Expanded(
                      flex: 1,
                      child: _buildHeroText(primaryBlue),
                    ),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    flex: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Container(
                            height: isNarrow ? 240 : 320,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8ECF8),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFEFF2FB),
                                  Color(0xFFDDE7FF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: image != null
                                ? Image.network(
                                    image,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 82,
                                      color: primaryBlue.withOpacity(0.5),
                                    ),
                                  ),
                          ),
                          if (!isAuthenticated)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () => showAuthDialog(context, startInRegister: true),
                                child: const Text('Inregistrati-va acum'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroText(Color primaryBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Colectii in editie limitata',
            style: TextStyle(
              color: Color(0xFF1B4BD6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Colectia\nLes Inrocks x Taskul',
          style: TextStyle(
            fontSize: 32,
            height: 1.2,
            color: primaryBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'De la filme cult la icoane ale muzicii, descoperiti proiecte selectate manual de expertii Taskul.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(
              label: const Text('Vezi colectia'),
              labelStyle: TextStyle(color: primaryBlue),
              backgroundColor: Colors.blue.shade50,
              onPressed: () {},
            ),
            const ActionChip(
              label: Text('Arta'),
              backgroundColor: Color(0xFFF2F5FF),
            ),
            const ActionChip(
              label: Text('Vintage'),
              backgroundColor: Color(0xFFF2F5FF),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectionStrip(Color primaryBlue) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.favorite_outline, color: Colors.black54),
          const SizedBox(width: 8),
          const Text(
            'Curatorii nostri au selectat pentru dvs.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right),
            label: Text(
              'Vezi toate colectiile',
              style: TextStyle(color: primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  SliverPadding _buildGridSection(Color primaryBlue, List<Task> tasks) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final crossAxisCount = width > 1160
              ? 4
              : width > 880
                  ? 3
                  : width > 620
                      ? 2
                      : 1;

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final task = tasks[index];
                final isLoading = _loadingActions.contains(task.id);
                return _TaskTile(
                  task: task,
                  isLoading: isLoading,
                  onAccept: () => _handleAction(task: task, accept: true),
                  onRefuse: () => _handleAction(task: task, accept: false),
                  onViewDetails: () => _openTaskDetails(task),
                  onViewOnMap: () => _showTaskOnMap(task),
                  primaryBlue: primaryBlue,
                );
              },
              childCount: tasks.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(Color primaryBlue, bool isAuthenticated) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 40,
            runSpacing: 16,
            children: [
              _FooterColumn(
                title: 'Despre Taskul',
                links: const [
                  'Cine suntem',
                  'Expertii nostri',
                  'Cariera',
                  'Presa',
                  'Parteneriate',
                ],
              ),
              _FooterColumn(
                title: 'Cumpararea',
                links: const [
                  'Cum puteti cumpara',
                  'Protectia cumparatorului',
                  'Povesti Taskul',
                  'Termeni cumparator',
                ],
              ),
              _FooterColumn(
                title: 'Vanzarea',
                links: const [
                  'Cum puteti vinde',
                  'Sfaturi vanzatori',
                  'Termeni vanzator',
                  'Afiliati',
                ],
              ),
              _FooterColumn(
                title: 'Contul meu',
                links: const [
                  'Conectare',
                  'Inregistrare',
                  'Centrul de ajutor',
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE3E6ED)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Romana'),
                    SizedBox(width: 6),
                    Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Icon(Icons.facebook_outlined, size: 22),
              SizedBox(width: 12),
              Icon(Icons.photo_camera_outlined, size: 22),
              SizedBox(width: 12),
              Icon(Icons.dark_mode_outlined, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: const [
                    Text('Termeni de utilizare'),
                    Text('Protectia datelor si confidentialitatea'),
                    Text('Politica de cookie-uri'),
                    Text('Politica de punere in aplicare a legii'),
                    Text('Alte politici'),
                    Text('© 2025'),
                  ],
                ),
              ),
              if (!AuthState.instance.isAuthenticated)
              if (!isAuthenticated)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => showAuthDialog(context, startInRegister: true),
                  child: const Text('Inregistrati-va acum'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final Color primaryBlue;

  const _Logo({required this.primaryBlue});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.shopping_bag,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Taskul',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: primaryBlue,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _NavPill({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDFE3EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 4),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<_CategoryItem> categories;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Color primaryBlue;

  _CategoryHeaderDelegate({
    required this.categories,
    required this.selectedIndex,
    required this.onTap,
    required this.primaryBlue,
  });

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: maxExtent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            if (overlapsContent)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < categories.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: selectedIndex == i,
                    showCheckmark: false,
                    avatar: Icon(
                      categories[i].icon,
                      size: 18,
                      color: selectedIndex == i ? primaryBlue : Colors.black54,
                    ),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(categories[i].label),
                    ),
                    selectedColor: primaryBlue.withOpacity(0.12),
                    backgroundColor: const Color(0xFFF7F8FB),
                    labelStyle: TextStyle(
                      color: selectedIndex == i ? primaryBlue : Colors.black87,
                      fontWeight: selectedIndex == i
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onSelected: (_) => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.categories != categories;
  }
}

class _CategoryItem {
  final String label;
  final IconData icon;

  const _CategoryItem({
    required this.label,
    required this.icon,
  });
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback onViewDetails;
  final VoidCallback onViewOnMap;
  final Color primaryBlue;

  const _TaskTile({
    required this.task,
    required this.isLoading,
    required this.onAccept,
    required this.onRefuse,
    required this.onViewDetails,
    required this.onViewOnMap,
    required this.primaryBlue,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final image = (task.images.isNotEmpty) ? task.images.first : null;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2FB),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEFF2FB),
                            Color(0xFFDDE7FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: image != null
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                            )
                          : Icon(
                              Icons.image_outlined,
                              size: 56,
                              color: primaryBlue.withOpacity(0.6),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_pin,
                              size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            task.shortAddress,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: onViewOnMap,
                      icon: const Icon(Icons.favorite_border),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      task.statusLabel,
                      style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start ${_formatTime(task.startTime)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'de ${task.creatorName}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.shortAddress,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Oferta curenta',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        '${task.price.toStringAsFixed(0)} lei',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isLoading ? null : onAccept,
                    child: isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accepta'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: isLoading ? null : onRefuse,
                    child: const Text('Refuza'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: onViewDetails,
                    child: const Text('Vezi detalii'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onViewOnMap,
                    icon: const Icon(Icons.map_outlined),
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

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _FooterColumn({
    required this.title,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          for (final link in links) ...[
            Text(
              link,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
