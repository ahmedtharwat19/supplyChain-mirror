import 'package:flutter/material.dart';

class HoverAddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double iconSize;
  final String? tooltip;
  final IconData icon;
  final Color? iconColor;

  const HoverAddButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.iconSize = 24,
    this.tooltip,
    this.iconColor,
  });

  @override
  State<HoverAddButton> createState() => _HoverAddButtonState();
}

class _HoverAddButtonState extends State<HoverAddButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0,
      upperBound: 0.1, // slight rotation
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent event) {
    setState(() => _isHovering = true);
    _rotationController.forward();
  }

  void _onExit(PointerEvent event) {
    setState(() => _isHovering = false);
    _rotationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: AnimatedScale(
        scale: _isHovering ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: RotationTransition(
          turns: _rotationController,
          child: IconButton(
            icon: Icon(widget.icon, size: widget.iconSize, color: widget.iconColor),
            tooltip: widget.tooltip,
            onPressed: widget.onPressed,
          ),
        ),
      ),
    );
  }
}
