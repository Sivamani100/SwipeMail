import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/swipe/swipe_provider.dart';

class TinderCard extends StatefulWidget {
  final SwipeCard card;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onTap;
  final VoidCallback? onReviewIndividually;

  const TinderCard({
    super.key,
    required this.card,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onTap,
    this.onReviewIndividually,
  });

  @override
  State<TinderCard> createState() => _TinderCardState();
}

class _TinderCardState extends State<TinderCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.35; // 35% swipe threshold

    if (_dragOffset.dx > threshold) {
      // Swipe Right -> Keep
      _animateOut(right: true);
    } else if (_dragOffset.dx < -threshold) {
      // Swipe Left -> Delete
      _animateOut(right: false);
    } else {
      // Spring back to center
      _animateBack();
    }
  }

  void _animateBack() {
    final startOffset = _dragOffset;
    
    _animController.reset();
    final Animation<Offset> offsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _animController.addListener(() {
      setState(() {
        _dragOffset = offsetAnimation.value;
      });
    });

    _animController.forward();
  }

  void _animateOut({required bool right}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = right ? screenWidth * 1.5 : -screenWidth * 1.5;
    final startOffset = _dragOffset;

    _animController.reset();
    final Animation<Offset> offsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset(targetX, startOffset.dy),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.addListener(() {
      setState(() {
        _dragOffset = offsetAnimation.value;
      });
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (right) {
          widget.onSwipeRight();
        } else {
          widget.onSwipeLeft();
        }
      }
    });

    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.9;
    final cardHeight = size.height * 0.6;

    // Calculate rotation angle (max 15 degrees)
    final rotation = (_dragOffset.dx / size.width) * (pi / 12);

    // Calculate opacity of Keep/Trash overlays
    final keepOpacity = min(max(_dragOffset.dx / 100.0, 0.0), 1.0);
    final trashOpacity = min(max(-_dragOffset.dx / 100.0, 0.0), 1.0);

    return Positioned(
      left: (size.width - cardWidth) / 2,
      top: (size.height - cardHeight) / 2.5,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTap: widget.onTap,
        child: Transform.translate(
          offset: _dragOffset,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: _isDragging ? 1.03 : 1.0,
              child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Stack(
                children: [
                  // The core Card Content
                  Positioned.fill(
                    child: widget.card.type == CardType.individual
                        ? _buildIndividualCard()
                        : _buildBulkCard(),
                  ),

                  // "KEEP" Overlay Indicator
                  if (keepOpacity > 0)
                    Positioned(
                      top: 40,
                      left: 30,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Opacity(
                          opacity: keepOpacity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF00B894), width: 4),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF00B894).withOpacity(0.1),
                            ),
                            child: const Text(
                              'KEEP',
                              style: TextStyle(
                                color: Color(0xFF00B894),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // "REMOVE" Overlay Indicator
                  if (trashOpacity > 0)
                    Positioned(
                      top: 40,
                      right: 30,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Opacity(
                          opacity: trashOpacity,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD63031), width: 4),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFD63031).withOpacity(0.1),
                            ),
                            child: const Text(
                              'REMOVE',
                              style: TextStyle(
                                color: Color(0xFFD63031),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildIndividualCard() {
    final email = widget.card.email!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Avatar initials and background color based on name hash
    final initials = email.senderName.isNotEmpty ? email.senderName[0].toUpperCase() : '@';
    final colors = [
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.red
    ];
    final avatarColor = colors[email.senderName.hashCode % colors.length];

    final dateStr = DateFormat('MMM dd, yyyy').format(email.date);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor,
                  radius: 24,
                  child: Text(
                    initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.senderName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        email.senderEmail,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2C274C)),
            const SizedBox(height: 12),
            Text(
              email.subject,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                email.snippet,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 7,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap card to expand full view',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      // Customize look for bulk cleaning card (different gradient border or background)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: primaryColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread,
                size: 56,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bulk Cleanup Recommendation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have ${widget.card.emailCount} emails from:',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.card.senderName ?? '',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '(${widget.card.senderEmail})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const Divider(color: Color(0xFF2C274C)),
            const SizedBox(height: 12),
            Text(
              'Swipe Right to KEEP ALL or Swipe Left to REMOVE ALL',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (widget.onReviewIndividually != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onReviewIndividually,
                  icon: const Icon(Icons.playlist_play),
                  label: const Text('Review Individually'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
