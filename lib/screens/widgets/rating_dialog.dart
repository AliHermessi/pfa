import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final String mecanicienNom;

  const RatingDialog({super.key, required this.mecanicienNom});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _note = 5;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Évaluer l\'intervention', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Comment s\'est passée l\'intervention avec ${widget.mecanicienNom} ?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _note ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB300),
                  size: 36,
                ),
                onPressed: () {
                  setState(() {
                    _note = index + 1;
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 8),
          Text('$_note étoile${_note > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, _note),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
