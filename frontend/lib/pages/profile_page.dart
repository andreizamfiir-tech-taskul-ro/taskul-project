import 'package:flutter/material.dart';

import '../api/business_api.dart';
import '../api/notifications_api.dart';
import '../api/tasks_api.dart';
import '../models/business.dart';
import '../models/notification_item.dart';
import '../models/task.dart';
import '../state/auth_state.dart';
import '../widgets/auth_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isCompany = false;
  _BusinessData? _businessData;
  int? _loadedUserId;
  bool _isBusinessLoading = false;
  bool _isBusinessSaving = false;
  bool _isNotificationsLoading = false;
  bool _isNotificationsDialogLoading = false;
  List<NotificationItem> _notifications = [];
  int _unreadNotifications = 0;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0040FF);
    const darkBg = Color(0xFF0F172A);
    const cardBg = Color(0xFF111827);

    final auth = AuthState.instance;

    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isAuthenticated || auth.user == null) {
          return _LoggedOutScaffold(primaryBlue: primaryBlue);
        }

        final user = auth.user!;
        if (_loadedUserId != user.id) {
          _loadedUserId = user.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadBusiness(user.id);
            _loadNotifications(user.id);
          });
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        primaryBlue: primaryBlue,
                        darkBg: darkBg,
                        userName: user.name,
                        email: user.email,
                        emailVerified: user.emailVerifiedAt != null,
                        phoneVerified: user.phoneVerifiedAt != null,
                        onLogout: auth.logout,
                      ),
                      const SizedBox(height: 12),
                      _StatsRow(cardBg: cardBg, primaryBlue: primaryBlue),
                      const SizedBox(height: 12),
                      _AboutSection(cardBg: cardBg, primaryBlue: primaryBlue),
                      const SizedBox(height: 12),
                      _ContentSection(cardBg: cardBg, primaryBlue: primaryBlue),
                      const SizedBox(height: 12),
                      _SettingsSection(
                        cardBg: cardBg,
                        primaryBlue: primaryBlue,
                        isCompany: _isCompany,
                        businessData: _businessData,
                        isLoading: _isBusinessLoading || _isBusinessSaving,
                        unreadNotifications: _unreadNotifications,
                        isNotificationsLoading: _isNotificationsLoading,
                        onToggleCompany: _handleCompanyToggle,
                        onEditCompany: _handleCompanyEdit,
                        onOpenInvoices: _openInvoicesDialog,
                        onOpenNotifications: _openNotificationsDialog,
                      ),
                      const SizedBox(height: 12),
                      _SidebarSection(cardBg: cardBg, primaryBlue: primaryBlue),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCompanyToggle(bool value) async {
    if (!value) {
      final user = AuthState.instance.user;
      if (user == null) return;
      setState(() => _isBusinessSaving = true);
      try {
        await BusinessApi.deleteBusiness(userId: user.id);
        if (!mounted) return;
        setState(() {
          _isCompany = false;
          _businessData = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nu am putut dezactiva firma: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isBusinessSaving = false);
      }
      return;
    }

    final data = await _openCompanyDialog();
    if (!mounted) return;
    if (data != null) {
      await _saveBusiness(data);
    } else {
      setState(() {
        _isCompany = false;
      });
    }
  }

  Future<_BusinessData?> _openCompanyDialog() async {
    final nameCtrl = TextEditingController(text: _businessData?.name ?? '');
    final descCtrl = TextEditingController(text: _businessData?.description ?? '');
    final addrCtrl = TextEditingController(text: _businessData?.address ?? '');
    final cityCtrl = TextEditingController(text: _businessData?.city ?? '');
    final countryCtrl = TextEditingController(text: _businessData?.country ?? '');
    final websiteCtrl = TextEditingController(text: _businessData?.website ?? '');
    final emailCtrl = TextEditingController(text: _businessData?.email ?? '');
    final phoneCtrl = TextEditingController(text: _businessData?.phone ?? '');
    String? errorText;

    final result = await showDialog<_BusinessData>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void autofill() {
              nameCtrl.text = 'Taskul Services SRL';
              descCtrl.text = 'Servicii rapide pentru taskuri casnice si business.';
              addrCtrl.text = 'Str. Exemplu 10';
              cityCtrl.text = 'Bucuresti';
              countryCtrl.text = 'Romania';
              websiteCtrl.text = 'https://taskul.ro';
              emailCtrl.text = 'office@taskul.ro';
              phoneCtrl.text = '+40 712 345 678';
            }

            InputDecoration fieldDecoration(String label) {
              return InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              );
            }

            return AlertDialog(
              title: const Text('Date firma'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: autofill,
                        child: const Text('Autofill'),
                      ),
                    ),
                    TextField(
                      controller: nameCtrl,
                      decoration: fieldDecoration('Denumire firma*'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: fieldDecoration('Descriere'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addrCtrl,
                      decoration: fieldDecoration('Adresa'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cityCtrl,
                      decoration: fieldDecoration('Oras'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: countryCtrl,
                      decoration: fieldDecoration('Tara'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: websiteCtrl,
                      decoration: fieldDecoration('Website'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      decoration: fieldDecoration('Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      decoration: fieldDecoration('Telefon'),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Anuleaza'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      setState(() {
                        errorText = 'Completeaza campurile obligatorii.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(
                      _BusinessData(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        address: addrCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        country: countryCtrl.text.trim(),
                        website: websiteCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Salveaza'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    descCtrl.dispose();
    addrCtrl.dispose();
    cityCtrl.dispose();
    countryCtrl.dispose();
    websiteCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    return result;
  }

  Future<void> _handleCompanyEdit() async {
    final data = await _openCompanyDialog();
    if (!mounted) return;
    if (data != null) {
      await _saveBusiness(data);
    }
  }

  Future<void> _loadBusiness(int userId) async {
    setState(() => _isBusinessLoading = true);
    try {
      final business = await BusinessApi.fetchBusiness(userId: userId);
      if (!mounted) return;
      setState(() {
        _businessData =
            business == null ? null : _BusinessData.fromBusiness(business);
        _isCompany = business != null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut incarca datele firmei: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusinessLoading = false);
    }
  }

  Future<void> _saveBusiness(_BusinessData data) async {
    final user = AuthState.instance.user;
    if (user == null) return;
    setState(() => _isBusinessSaving = true);
    try {
      final saved = await BusinessApi.upsertBusiness(
        userId: user.id,
        draft: data.toDraft(),
      );
      if (!mounted) return;
      setState(() {
        _businessData = _BusinessData.fromBusiness(saved);
        _isCompany = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date firma actualizate')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut salva datele firmei: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusinessSaving = false);
    }
  }

  Future<void> _loadNotifications(int userId) async {
    setState(() => _isNotificationsLoading = true);
    try {
      final count = await NotificationsApi.fetchUnreadCount(userId: userId);
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut incarca notificarile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isNotificationsLoading = false);
    }
  }

  Future<void> _openNotificationsDialog() async {
    final user = AuthState.instance.user;
    if (user == null) return;
    setState(() => _isNotificationsDialogLoading = true);
    try {
      final items = await NotificationsApi.fetchNotifications(userId: user.id);
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isNotificationsDialogLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isNotificationsDialogLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut incarca notificarile: $e')),
        );
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Notificari'),
          content: SizedBox(
            width: 520,
            child: _isNotificationsDialogLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? const Text('Nu ai notificari.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          return _NotificationRow(
                            item: item,
                            onMarkRead: () => _markNotificationRead(item),
                          );
                        },
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _markAllNotificationsRead();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Marcheaza toate citite'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Inchide'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markNotificationRead(NotificationItem item) async {
    final user = AuthState.instance.user;
    if (user == null || item.isRead) return;
    try {
      await NotificationsApi.markRead(
        userId: user.id,
        notificationId: item.id,
      );
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id != item.id) return n;
          return NotificationItem(
            id: n.id,
            profileId: n.profileId,
            type: n.type,
            payload: n.payload,
            isRead: true,
            createdAt: n.createdAt,
          );
        }).toList();
        _unreadNotifications =
            (_unreadNotifications - 1).clamp(0, 9999);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut marca notificarea: $e')),
        );
      }
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final user = AuthState.instance.user;
    if (user == null) return;
    try {
      await NotificationsApi.markAllRead(userId: user.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => NotificationItem(
                  id: n.id,
                  profileId: n.profileId,
                  type: n.type,
                  payload: n.payload,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
        _unreadNotifications = 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nu am putut marca toate notificarile: $e')),
        );
      }
    }
  }

  Future<void> _openInvoicesDialog() async {
    final user = AuthState.instance.user;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Facturi'),
          content: SizedBox(
            width: 520,
            child: FutureBuilder<List<Task>>(
              future: fetchMyTasks(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Eroare: ${snapshot.error}');
                }
                final tasks = snapshot.data ?? [];
                final paid = tasks
                    .where((t) => t.creatorId == user.id && t.statusId == 3)
                    .toList();

                if (paid.isEmpty) {
                  return const Text('Nu ai task-uri platite pentru facturare.');
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: paid.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final task = paid[index];
                    final number = _formatInvoiceNumber(task);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Factura $number • ${task.price.toStringAsFixed(0)} lei',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _openInvoiceTemplate(task);
                          },
                          child: const Text('Descarca'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Inchide'),
            ),
          ],
        );
      },
    );
  }

  String _formatInvoiceNumber(Task task) {
    final year = task.startTime.year;
    return 'INV-$year-${task.id.toString().padLeft(4, '0')}';
  }

  Future<void> _openInvoiceTemplate(Task task) async {
    final user = AuthState.instance.user;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _InvoiceTemplate(
                number: _formatInvoiceNumber(task),
                task: task,
                issuer: _businessData,
                issuerFallbackName: user.name,
                issuerEmail: user.email,
                onDownload: () => _downloadInvoicePdf(task),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadInvoicePdf(Task task) async {
    final user = AuthState.instance.user;
    if (user == null) return;

    final number = _formatInvoiceNumber(task);
    final issuerName = _businessData?.name ?? user.name;
    final issuerAddress = _businessData?.address.isNotEmpty == true
        ? _businessData!.address
        : '-';
    final issuerCity = _businessData?.city.isNotEmpty == true
        ? _businessData!.city
        : '';
    final issuerCountry = _businessData?.country.isNotEmpty == true
        ? _businessData!.country
        : '';
    final issuerEmail = _businessData?.email.isNotEmpty == true
        ? _businessData!.email
        : user.email;
    final issuerPhone = _businessData?.phone.isNotEmpty == true
        ? _businessData!.phone
        : '';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Factura',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(number),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _pdfBlock(
                      title: 'Emitent',
                      lines: [
                        issuerName,
                        issuerAddress,
                        [issuerCity, issuerCountry]
                            .where((e) => e.isNotEmpty)
                            .join(', '),
                        issuerEmail,
                        issuerPhone,
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: _pdfBlock(
                      title: 'Beneficiar',
                      lines: [
                        task.assignedName ?? 'Client',
                        task.shortAddress,
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              _pdfTable(task),
              pw.SizedBox(height: 18),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total: ${task.price.toStringAsFixed(0)} lei',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: '$number.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  pw.Widget _pdfBlock({required String title, required List<String> lines}) {
    final displayLines = lines.where((e) => e.isNotEmpty).toList();
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 6),
          ...displayLines.map((line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text(line),
              )),
        ],
      ),
    );
  }

  pw.Widget _pdfTable(Task task) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _pdfTableCell('Serviciu', isHeader: true),
            _pdfTableCell('Cant.', isHeader: true),
            _pdfTableCell('Pret', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfTableCell(task.title),
            _pdfTableCell('1'),
            _pdfTableCell('${task.price.toStringAsFixed(0)} lei'),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Color primaryBlue;
  final Color darkBg;
  final String userName;
  final String email;
  final VoidCallback onLogout;
  final bool emailVerified;
  final bool phoneVerified;

  const _Header({
    required this.primaryBlue,
    required this.darkBg,
    required this.userName,
    required this.email,
    required this.onLogout,
    required this.emailVerified,
    required this.phoneVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: darkBg,
            image: const DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1400&q=80',
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.45),
                Colors.black.withOpacity(0.65),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      foregroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onLogout,
                    child: const Text('Deconectare'),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const CircleAvatar(
                        radius: 36,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=crop&w=400&q=80',
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Profil personal',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              'In platforma din 2024',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _VerificationPill(
                      icon: Icons.email_outlined,
                      label: emailVerified ? 'Email verificat' : 'Email nevalidat',
                      color: emailVerified ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _VerificationPill(
                      icon: Icons.phone_iphone,
                      label: phoneVerified ? 'Telefon verificat' : 'Telefon nevalidat',
                      color: phoneVerified ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerificationPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _VerificationPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggedOutScaffold extends StatelessWidget {
  final Color primaryBlue;

  const _LoggedOutScaffold({required this.primaryBlue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Pentru a vedea profilul, conectati-va sau creati un cont.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
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
                child: const Text('Conectare / Inregistrare'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Color cardBg;
  final Color primaryBlue;

  const _StatsRow({
    required this.cardBg,
    required this.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Task-uri finalizate', '930'),
      ('Rating', '4.8'),
      ('Recenzii', '112'),
      ('Urmaritori', '1.2K'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: stats
            .map(
              (item) => Container(
                width: 160,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$1,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final Color cardBg;
  final Color primaryBlue;

  const _AboutSection({
    required this.cardBg,
    required this.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
                SizedBox(width: 6),
                Text(
                  'Despre mine',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pasionat de proiecte hands-on si logistica. Iubesc sa lucrez cu echipe diverse si sa livrez rapid.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Disponibil', primaryBlue),
                _chip('Bucuresti', primaryBlue),
                _chip('Logistica', primaryBlue),
                _chip('Evenimente', primaryBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ContentSection extends StatelessWidget {
  final Color cardBg;
  final Color primaryBlue;

  const _ContentSection({
    required this.cardBg,
    required this.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Suport eveniment corporate',
        'Am coordonat logistica pentru un eveniment de 300+ participanti, cu rating 4.9.',
        'https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=1000&q=80'
      ),
      (
        'Transport piese mobilier',
        'Livrare si montaj pentru 12 locatii in 2 zile, feedback 5.0.',
        'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1000&q=80'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ultimele proiecte',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: Image.network(
                      item.$3,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.favorite, color: primaryBlue, size: 16),
                            const SizedBox(width: 4),
                            const Text('4.9', style: TextStyle(color: Colors.white)),
                            const Spacer(),
                            TextButton(
                              onPressed: () {},
                              child: const Text('Vezi detalii'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final Color cardBg;
  final Color primaryBlue;

  const _SidebarSection({
    required this.cardBg,
    required this.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistici rapide',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Rata acceptare',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '86.9%',
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      Text(
                        'Rata finalizare',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '92.4%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leaderboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(3, (index) {
                  final ranks = ['Gold', 'Platinum', 'Diamond'];
                  final names = ['Simmycool', 'Nolan Jnr', 'Ana M.'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                names[index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                ranks[index],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rank ${index + 4}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final Color cardBg;
  final Color primaryBlue;
  final bool isCompany;
  final _BusinessData? businessData;
  final bool isLoading;
  final int unreadNotifications;
  final bool isNotificationsLoading;
  final ValueChanged<bool> onToggleCompany;
  final Future<void> Function() onEditCompany;
  final VoidCallback onOpenInvoices;
  final VoidCallback onOpenNotifications;

  const _SettingsSection({
    required this.cardBg,
    required this.primaryBlue,
    required this.isCompany,
    required this.businessData,
    required this.isLoading,
    required this.unreadNotifications,
    required this.isNotificationsLoading,
    required this.onToggleCompany,
    required this.onEditCompany,
    required this.onOpenInvoices,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Setari profil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isCompany ? 'Persoana juridica' : 'Persoana fizica',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                Switch(
                  value: isCompany,
                  onChanged: isLoading ? null : onToggleCompany,
                  activeColor: primaryBlue,
                ),
              ],
            ),
            if (isCompany) ...[
              const SizedBox(height: 10),
              if (businessData != null)
                _BusinessSummary(
                  data: businessData!,
                  primaryBlue: primaryBlue,
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: isLoading ? null : onEditCompany,
                  child: const Text('Editeaza datele firmei'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenInvoices,
                child: const Text('Facturi'),
              ),
            ),
            const SizedBox(height: 6),
            _NotificationBadge(
              count: unreadNotifications,
              isLoading: isNotificationsLoading,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenNotifications,
                child: const Text('Vezi notificari'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessSummary extends StatelessWidget {
  final _BusinessData data;
  final Color primaryBlue;

  const _BusinessSummary({
    required this.data,
    required this.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Denumire', data.name),
      if (data.description.isNotEmpty) ('Descriere', data.description),
      if (data.address.isNotEmpty) ('Adresa', data.address),
      if (data.city.isNotEmpty) ('Oras', data.city),
      if (data.country.isNotEmpty) ('Tara', data.country),
      if (data.website.isNotEmpty) ('Website', data.website),
      if (data.email.isNotEmpty) ('Email', data.email),
      if (data.phone.isNotEmpty) ('Telefon', data.phone),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BusinessData {
  final String name;
  final String description;
  final String address;
  final String city;
  final String country;
  final String website;
  final String email;
  final String phone;

  const _BusinessData({
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.country,
    required this.website,
    required this.email,
    required this.phone,
  });

  factory _BusinessData.fromBusiness(Business business) {
    return _BusinessData(
      name: business.name,
      description: business.description ?? '',
      address: business.address ?? '',
      city: business.city ?? '',
      country: business.country ?? '',
      website: business.website ?? '',
      email: business.email ?? '',
      phone: business.phone ?? '',
    );
  }

  BusinessDraft toDraft() {
    return BusinessDraft(
      name: name,
      description: description.isEmpty ? null : description,
      address: address.isEmpty ? null : address,
      city: city.isEmpty ? null : city,
      country: country.isEmpty ? null : country,
      website: website.isEmpty ? null : website,
      email: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
    );
  }
}

class _InvoiceTemplate extends StatelessWidget {
  final String number;
  final Task task;
  final _BusinessData? issuer;
  final String issuerFallbackName;
  final String issuerEmail;
  final VoidCallback onDownload;

  const _InvoiceTemplate({
    required this.number,
    required this.task,
    required this.issuer,
    required this.issuerFallbackName,
    required this.issuerEmail,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final issuerName = issuer?.name ?? issuerFallbackName;
    final issuerAddress = issuer?.address.isNotEmpty == true
        ? issuer!.address
        : '-';
    final issuerCity = issuer?.city.isNotEmpty == true ? issuer!.city : '';
    final issuerCountry =
        issuer?.country.isNotEmpty == true ? issuer!.country : '';
    final issuerPhone = issuer?.phone.isNotEmpty == true ? issuer!.phone : '';
    final issuerWebsite =
        issuer?.website.isNotEmpty == true ? issuer!.website : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Factura',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              number,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _InvoiceBlock(
                title: 'Emitent',
                lines: [
                  issuerName,
                  issuerAddress,
                  [issuerCity, issuerCountry].where((e) => e.isNotEmpty).join(', '),
                  issuerEmail,
                  issuerPhone,
                  issuerWebsite,
                ].where((e) => e.isNotEmpty).toList(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InvoiceBlock(
                title: 'Beneficiar',
                lines: [
                  task.assignedName ?? 'Client',
                  task.shortAddress,
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InvoiceTable(task: task),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Total de plata',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${task.price.toStringAsFixed(0)} lei',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download),
            label: const Text('Descarca factura'),
          ),
        ),
      ],
    );
  }
}

class _InvoiceBlock extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _InvoiceBlock({
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E6F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTable extends StatelessWidget {
  final Task task;

  const _InvoiceTable({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E6F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F5FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Serviciu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cant.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Pret',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(task.title)),
                const Expanded(child: Text('1')),
                Expanded(child: Text('${task.price.toStringAsFixed(0)} lei')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;
  final bool isLoading;

  const _NotificationBadge({
    required this.count,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.notifications_none, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        const Text(
          'Notificari',
          style: TextStyle(color: Colors.white70),
        ),
        const Spacer(),
        if (isLoading)
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onMarkRead;

  const _NotificationRow({
    required this.item,
    required this.onMarkRead,
  });

  String _titleForType() {
    final payload = item.payload;
    final title = payload['title']?.toString();
    switch (item.type) {
      case 'task_accepted':
        return title != null ? 'Task acceptat: $title' : 'Task acceptat';
      case 'task_assigned':
        return title != null ? 'Task asignat: $title' : 'Task asignat';
      case 'task_reminder':
        final kind = payload['kind']?.toString() ?? '';
        final prefix = kind == '45m' ? 'Reminder 45m' : 'Reminder 1h';
        return title != null ? '$prefix: $title' : prefix;
      case 'task_unassigned_warning':
        return title != null
            ? 'Task neasignat (1h): $title'
            : 'Task neasignat (1h)';
      default:
        return title ?? 'Notificare';
    }
  }

  String _subtitle() {
    final created = item.createdAt;
    return '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year} '
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.isRead ? null : onMarkRead,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isRead ? Icons.notifications : Icons.notifications_active,
            color: item.isRead ? Colors.black45 : Colors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleForType(),
                  style: TextStyle(
                    fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!item.isRead)
            TextButton(
              onPressed: onMarkRead,
              child: const Text('Marcheaza citit'),
            ),
        ],
      ),
    );
  }
}
