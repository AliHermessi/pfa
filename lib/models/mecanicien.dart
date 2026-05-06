class Mecanicien {
  final String id;
  final String nom;
  final String specialite;
  final double note;
  final int nombreAvis;
  final double distanceKm;
  final bool disponible;
  final String telephone;

  Mecanicien({
    required this.id,
    required this.nom,
    required this.specialite,
    required this.note,
    required this.nombreAvis,
    required this.distanceKm,
    required this.disponible,
    required this.telephone,
  });

  String get initiales {
    final parts = nom.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.substring(0, 2).toUpperCase();
  }
}
