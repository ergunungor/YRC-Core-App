import 'package:flutter/material.dart';
import '../services/pacer_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final PacerService _pacerService = PacerService();
  final Color _bgColor = const Color(0xFF01132A);

  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String? _processingId; // hangi başvuru işleniyor, buton spinner'ı için

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final apps = await _pacerService.fetchPendingApplications();
      if (mounted) {
        setState(() {
          _applications = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Başvurular yüklenemedi: $e')));
      }
    }
  }

  Future<void> _approve(Map<String, dynamic> application) async {
    setState(() => _processingId = application['id']);
    try {
      await _pacerService.approveApplication(
        applicationId: application['id'],
        stravaId: application['strava_id'],
      );
      await _loadApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Onaylanamadı: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> application) async {
    setState(() => _processingId = application['id']);
    try {
      await _pacerService.rejectApplication(application['id']);
      await _loadApplications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reddedilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text(
          'Pacer Başvuruları',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
              : _applications.isEmpty
              ? const Center(
                child: Text(
                  'Bekleyen başvuru yok.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadApplications,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _applications.length,
                  itemBuilder: (context, index) {
                    final app = _applications[index];

                    final String fullName =
                        '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}'
                            .trim();

                    final String avatarUrl =
                        (app['avatar_url'] as String?) ?? '';

                    final bool isProcessing = _processingId == app['id'];

                    return Card(
                      color: Colors.white.withValues(alpha: 0.08),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              avatarUrl.isNotEmpty
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child:
                              avatarUrl.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                        ),
                        title: Text(
                          fullName.isEmpty ? 'İsimsiz Koşucu' : fullName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Strava ID: ${app['strava_id']}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing:
                            isProcessing
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.greenAccent,
                                      ),
                                      onPressed: () => _approve(app),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.cancel_rounded,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _reject(app),
                                    ),
                                  ],
                                ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
