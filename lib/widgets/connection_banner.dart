import 'package:flutter/cupertino.dart';

class ConnectionBanner extends StatelessWidget {
  final String message;
  final Color? color;

  const ConnectionBanner({
    super.key,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: (color ?? CupertinoColors.systemOrange).withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
