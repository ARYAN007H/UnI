import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';

class MemoryGlobeScreen extends StatefulWidget {
  final ChatService chatService;
  final AuthService authService;

  const MemoryGlobeScreen({
    super.key,
    required this.chatService,
    required this.authService,
  });

  @override
  State<MemoryGlobeScreen> createState() => _MemoryGlobeScreenState();
}

class _MemoryGlobeScreenState extends State<MemoryGlobeScreen> {
  late FlutterEarthGlobeController _controller;
  List<Message> _memoryMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05,
      isDayNightCycleEnabled: true,
      zoom: 0.5,
    );

    _loadMemories();
  }

  Future<void> _loadMemories() async {
    final messages = await widget.chatService.getMessagesWithLocation();
    
    if (mounted) {
      setState(() {
        _memoryMessages = messages;
        _isLoading = false;
      });
      
      _plotMarkers();
    }
  }

  void _plotMarkers() {
    for (final msg in _memoryMessages) {
      if (msg.latitude == null || msg.longitude == null) continue;
      
      final isMine = msg.senderId == widget.authService.currentUser?.id;
      final pointColor = isMine ? AppTheme.primary : AppTheme.secondary;

      _controller.addPoint(
        Point(
          id: msg.id,
          coordinates: GlobeCoordinates(msg.latitude!, msg.longitude!),
          label: msg.content != null && msg.content!.isNotEmpty 
              ? msg.content 
              : 'Memory',
          isLabelVisible: false,
          style: PointStyle(
            color: pointColor,
            size: 8,
          ),
          onTap: () {
            _showMemoryDetails(msg);
          },
        ),
      );
    }
  }

  void _showMemoryDetails(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (message.mediaUrl != null)
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: message.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${message.latitude!.toStringAsFixed(4)}, ${message.longitude!.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat.yMMMd().add_jm().format(message.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (message.content != null && message.content!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        message.content!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Memory Globe',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF1E2430), Color(0xFF0F1218)],
                radius: 1.5,
              ),
            ),
          ),
          SafeArea(
            child: FlutterEarthGlobe(
              controller: _controller,
              radius: 120, // Optional if we want a smaller globe
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          
          if (!_isLoading && _memoryMessages.isEmpty)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'No geotagged memories yet.\nSend photos with location enabled to see them on the globe!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
