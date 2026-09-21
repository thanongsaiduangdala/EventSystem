import 'dart:async';

import 'package:flutter/material.dart';

/// Horizontally scrolling row that advances itself on a timer. Dragging the
/// list pauses the timer and takes full control; it resumes a while after the
/// user lets go, continuing from wherever they left off. Used by the "Near
/// You" section on the home page.
class NearbyAutoScroll extends StatefulWidget {
  const NearbyAutoScroll({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.itemHeight,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.interval = const Duration(seconds: 3),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;
  final double itemHeight;
  final double spacing;
  final EdgeInsets padding;
  final Duration interval;

  @override
  State<NearbyAutoScroll> createState() => _NearbyAutoScrollState();
}

class _NearbyAutoScrollState extends State<NearbyAutoScroll> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  int _index = 0;
  bool _userInteracting = false;
  Timer? _resumeTimer;

  double get _step => widget.itemWidth + widget.spacing;

  @override
  void initState() {
    super.initState();
    if (widget.itemCount > 1) _startTimer();
  }

  @override
  void didUpdateWidget(covariant NearbyAutoScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval ||
        oldWidget.itemCount != widget.itemCount) {
      _stopTimer();
      if (widget.itemCount > 1 && !_userInteracting) _startTimer();
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(widget.interval, (_) => _advance());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    final maxExtent =
        _controller.position.maxScrollExtent - _controller.position.minScrollExtent;
    if (maxExtent <= 0) return;

    final nextIndex = _index + 1;
    final nextOffset = nextIndex * _step - widget.padding.left;
    if (nextOffset > maxExtent + _step / 2) {
      _index = 0;
      _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _index = nextIndex;
      _controller.animateTo(
        nextOffset.clamp(0.0, maxExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onUserScrollStart() {
    _userInteracting = true;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _stopTimer();
    _index = ((_controller.offset + widget.padding.left) / _step).round();
  }

  void _onUserScrollEnd() {
    if (_resumeTimer != null) return;
    _resumeTimer = Timer(widget.interval, () {
      _resumeTimer = null;
      if (!mounted) return;
      _userInteracting = false;
      _startTimer();
    });
  }

  @override
  void dispose() {
    _stopTimer();
    _resumeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (notification.dragDetails != null) _onUserScrollStart();
        } else if (notification is ScrollEndNotification) {
          if (notification.dragDetails != null) _onUserScrollEnd();
        }
        return false;
      },
      child: SizedBox(
        height: widget.itemHeight,
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          itemCount: widget.itemCount,
          separatorBuilder: (_, __) => SizedBox(width: widget.spacing),
          itemBuilder: (context, index) => SizedBox(
            width: widget.itemWidth,
            child: widget.itemBuilder(context, index),
          ),
        ),
      ),
    );
  }
}