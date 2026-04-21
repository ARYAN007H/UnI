import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/typing_indicator.dart';

/// Fun interactive playground for the #random channel.
class RandomScreen extends StatefulWidget {
  final Channel channel;
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;

  const RandomScreen({super.key, required this.channel, required this.authService, required this.chatService, required this.presenceService});

  @override
  State<RandomScreen> createState() => _RandomScreenState();
}

class _RandomScreenState extends State<RandomScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _typingTimer;
  final _rng = Random();

  // Mini-game states
  int? _diceResult;
  bool? _coinResult;
  String? _spinnerResult;
  int? _loveMeter;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _load() async {
    await widget.chatService.loadMessages(widget.channel.id);
    widget.chatService.subscribeToMessages(widget.channel.id);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      widget.chatService.loadMessages(widget.channel.id, loadMore: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.chatService.unsubscribeFromMessages();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cc = AppTheme.colorsFor(ChannelType.random);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.channelBgGradient(ChannelType.random)),
        child: SafeArea(
          bottom: false,
          child: ResponsiveWrapper(maxWidth: 520, child: Column(children: [
            _appBar(cc),
            Expanded(child: _body(cc)),
            _inputBar(cc),
          ])),
        ),
      ),
    );
  }

  Widget _appBar(ChannelColors c) => ClipRRect(child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.85), border: Border(bottom: BorderSide(color: c.accent.withValues(alpha: 0.08)))),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), color: AppTheme.onSurface, onPressed: () => Navigator.pop(context)),
        Container(width: 38, height: 38, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart.withValues(alpha: 0.2), c.gradientEnd.withValues(alpha: 0.1)]), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('✨', style: TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#random', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text('Fun, games & vibes', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.accent, fontSize: 12)),
        ])),
      ]),
    ),
  ));

  Widget _body(ChannelColors c) {
    return ListenableBuilder(
      listenable: widget.chatService,
      builder: (context, _) {
        final messages = widget.chatService.messagesForChannel(widget.channel.id);
        final myId = widget.authService.currentUser!.id;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Prompt card
            SliverToBoxAdapter(child: _promptCard(c)),
            // Mini-games
            SliverToBoxAdapter(child: _miniGames(c)),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // Chat section header
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('CHAT', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), letterSpacing: 1.5, fontWeight: FontWeight.w600, fontSize: 10)),
            )),
            // Messages
            messages.isEmpty
                ? SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text('Share your random thoughts ✨', style: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13))),
                  ))
                : SliverList(delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final msg = messages[i]; final isMine = msg.senderId == myId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: MessageBubble(message: msg, isMine: isMine, showAvatar: !isMine && (i == messages.length - 1 || messages[i + 1].senderId != msg.senderId),
                          partnerProfile: widget.authService.partnerProfile, isVanillaMode: widget.authService.couple?.isVanillaMode ?? false,
                          onReply: () {}, onDelete: isMine ? () => widget.chatService.deleteMessage(msg.id, widget.channel.id) : null),
                      );
                    },
                    childCount: messages.length > 20 ? 20 : messages.length,
                  )),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // Typing indicator
            SliverToBoxAdapter(child: ListenableBuilder(listenable: widget.chatService, builder: (_, __) {
              if (!widget.chatService.partnerIsTyping) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Align(alignment: Alignment.centerLeft,
                child: TypingIndicatorWidget(name: widget.authService.partnerProfile?.displayName ?? 'Partner', isVanillaMode: widget.authService.couple?.isVanillaMode ?? false)));
            })),
          ],
        );
      },
    );
  }

  Widget _promptCard(ChannelColors c) {
    final prompt = widget.chatService.currentPrompt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GestureDetector(
        onTap: () { HapticFeedback.mediumImpact(); widget.chatService.nextRandomPrompt(); },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.gradientStart.withValues(alpha: 0.12), c.gradientEnd.withValues(alpha: 0.06)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.accent.withValues(alpha: 0.12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(prompt.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(prompt.category, style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                ])),
              const Spacer(),
              Text('Tap for new', style: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3), fontSize: 10)),
              Icon(Icons.refresh_rounded, size: 14, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3)),
            ]),
            const SizedBox(height: 14),
            Text(prompt.text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: AppTheme.onSurface, height: 1.4)),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _miniGames(ChannelColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('MINI GAMES', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), letterSpacing: 1.5, fontWeight: FontWeight.w600, fontSize: 10))),
        SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [
          _gameCard('🎲', 'Dice', _diceResult?.toString(), c, _rollDice),
          const SizedBox(width: 10),
          _gameCard('🪙', 'Flip', _coinResult == null ? null : (_coinResult! ? 'Heads' : 'Tails'), c, _flipCoin),
          const SizedBox(width: 10),
          _gameCard('🎰', 'Date Night', _spinnerResult, c, _spinWheel),
          const SizedBox(width: 10),
          _gameCard('❤️', 'Love-o-meter', _loveMeter == null ? null : '$_loveMeter%', c, _rollLove),
        ])),
      ]),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _gameCard(String emoji, String label, String? result, ChannelColors c, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isAnimating ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90, height: 90,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: result != null ? c.accent.withValues(alpha: 0.2) : AppTheme.outline.withValues(alpha: 0.1)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          if (result != null)
            Text(result, style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w700))
          else
            Text(label, style: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  void _rollDice() {
    HapticFeedback.mediumImpact();
    setState(() { _isAnimating = true; _diceResult = null; });
    // Quick animation: cycle through numbers
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() => _diceResult = _rng.nextInt(6) + 1);
      count++;
      if (count >= 8) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _isAnimating = false);
        _sendMessage('🎲 Rolled a $_diceResult!');
      }
    });
  }

  void _flipCoin() {
    HapticFeedback.mediumImpact();
    setState(() { _isAnimating = true; _coinResult = null; });
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() => _coinResult = _rng.nextBool());
      count++;
      if (count >= 6) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _isAnimating = false);
        _sendMessage('🪙 ${_coinResult! ? "Heads" : "Tails"}!');
      }
    });
  }

  void _spinWheel() {
    HapticFeedback.mediumImpact();
    setState(() { _isAnimating = true; _spinnerResult = null; });
    final options = SupabaseConfig.dateNightOptions;
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      setState(() => _spinnerResult = options[_rng.nextInt(options.length)].replaceAll(RegExp(r'^[^\s]+\s'), ''));
      count++;
      if (count >= 10) {
        timer.cancel();
        final result = options[_rng.nextInt(options.length)];
        HapticFeedback.heavyImpact();
        setState(() { _spinnerResult = result.replaceAll(RegExp(r'^[^\s]+\s'), ''); _isAnimating = false; });
        _sendMessage('🎰 Date Night Spinner says: $result');
      }
    });
  }

  void _rollLove() {
    HapticFeedback.mediumImpact();
    setState(() { _isAnimating = true; _loveMeter = null; });
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      setState(() => _loveMeter = _rng.nextInt(101));
      count++;
      if (count >= 12) {
        timer.cancel();
        // Always make it high because why not 💕
        final finalVal = 70 + _rng.nextInt(31);
        HapticFeedback.heavyImpact();
        setState(() { _loveMeter = finalVal; _isAnimating = false; });
        _sendMessage('❤️ Love-o-meter: $finalVal% 💕');
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    try {
      await widget.chatService.sendMessage(channelId: widget.channel.id, senderId: widget.authService.currentUser!.id, content: text);
    } catch (_) {}
  }

  Widget _inputBar(ChannelColors c) => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.95), border: Border(top: BorderSide(color: c.accent.withValues(alpha: 0.06)))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Container(decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.outlineVariant)),
        child: TextField(controller: _controller, focusNode: _focusNode,
          onChanged: (text) { if (text.isNotEmpty && widget.authService.couple != null) { _typingTimer?.cancel(); widget.chatService.sendTypingEvent(widget.authService.couple!.id, widget.authService.currentUser!.id); _typingTimer = Timer(const Duration(seconds: 2), () {}); } },
          onSubmitted: (_) => _sendText(),
          decoration: InputDecoration(hintText: 'Share a random thought...', hintStyle: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 15), contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
          textInputAction: TextInputAction.send, maxLines: 4, minLines: 1, style: TextStyle(color: AppTheme.onSurface, fontSize: 15)))),
      const SizedBox(width: 8),
      Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart, c.gradientEnd]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))]),
        child: Material(color: Colors.transparent, child: InkWell(onTap: _sendText, borderRadius: BorderRadius.circular(16), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)))),
    ]),
  );

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    HapticFeedback.lightImpact();
    await _sendMessage(text);
  }
}
