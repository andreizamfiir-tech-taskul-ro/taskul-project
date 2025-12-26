import 'package:flutter/material.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);
    final isWide = MediaQuery.of(context).size.width > 920;

    Widget leftPane = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Mesaje',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                _FilterChip(
                  label: 'Toate',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                  color: primaryBlue,
                ),
                _FilterChip(
                  label: 'Necitite',
                  selected: _filter == 'unread',
                  onTap: () => setState(() => _filter = 'unread'),
                  color: primaryBlue,
                ),
                _FilterChip(
                  label: 'Arhivat',
                  selected: _filter == 'archived',
                  onTap: () => setState(() => _filter = 'archived'),
                  color: primaryBlue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 42, color: Colors.grey.shade500),
                      const SizedBox(height: 12),
                      const Text(
                        'Nu exista mesaje',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Veti vedea un desfasurator al mesajelor dvs. aici.',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget rightPane = Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_outlined, size: 76, color: primaryBlue),
              const SizedBox(height: 14),
              const Text(
                'Incepeti o conversatie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Alegeti un mesaj din lista pentru a vedea detalii sau a raspunde.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: () {},
                child: const Text('Compune mesaj nou'),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Mesaje'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: isWide
            ? Row(
                children: [
                  SizedBox(width: 340, child: leftPane),
                  const SizedBox(width: 12),
                  Expanded(child: rightPane),
                ],
              )
            : Column(
                children: [
                  SizedBox(
                    height: 320,
                    child: leftPane,
                  ),
                  const SizedBox(height: 12),
                    Expanded(child: rightPane),
                ],
              ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withOpacity(0.12),
      labelStyle: TextStyle(
        color: selected ? color : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected ? color : Colors.grey.shade400,
        ),
      ),
    );
  }
}
