import 'package:flutter/material.dart';

class FloatingMicButton extends StatelessWidget {
  final VoidCallback onTap;

  const FloatingMicButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.mic, color: Colors.white),
      ),
    );
  }
}
