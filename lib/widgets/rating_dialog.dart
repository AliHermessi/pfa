import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final String mecanicienNom;
  const RatingDialog({super.key, required this.mecanicienNom});

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Noter ${widget.mecanicienNom}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ajouter un commentaire (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ANNULER'),
        ),
        ElevatedButton(
          onPressed: _rating == 0 ? null : () {
            // We return both rating and comment
            Navigator.pop(context, {
              'rating': _rating,
              'comment': _commentCtrl.text.trim(),
            });
          },
          child: const Text('VALIDER'),
        ),
      ],
    );
  }
}
