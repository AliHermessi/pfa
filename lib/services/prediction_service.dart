import '../models/vehicle.dart';
import '../models/intervention.dart';

class PredictionService {
  /// Calculates the average kilometers driven per day.
  /// Uses mileage history first, then falls back to intervention history.
  static double calculateAverageDailyKm(Vehicle vehicle, List<Intervention> history) {
    // 1. Try using mileage history (from GPS tracking)
    if (vehicle.mileageHistory.length >= 2) {
      final sortedHistory = List.from(vehicle.mileageHistory);
      sortedHistory.sort((a, b) => a.date.compareTo(b.date));
      
      final first = sortedHistory.first;
      final last = sortedHistory.last;
      
      final kmDiff = last.kilometrage - first.kilometrage;
      final daysDiff = last.date.difference(first.date).inDays;
      
      if (daysDiff > 0 && kmDiff > 0) {
        return kmDiff / daysDiff;
      }
    }

    // 2. Fallback: Use intervention history if available
    final vehicleHistory = history
        .where((i) => i.vehiculeId == vehicle.id && i.kilometrageCompteur != null)
        .toList();
    
    vehicleHistory.sort((a, b) => a.date.compareTo(b.date));

    if (vehicleHistory.length >= 2) {
      final first = vehicleHistory.first;
      final last = vehicleHistory.last;
      
      final kmDiff = last.kilometrageCompteur! - first.kilometrageCompteur!;
      final daysDiff = last.date.difference(first.date).inDays;
      
      if (daysDiff > 0 && kmDiff > 0) {
        return kmDiff / daysDiff;
      }
    }

    // 3. Last Fallback: Defaulting to a sensible average (e.g., 30 km/day)
    return 30.0; 
  }

  /// Predicts the date of the next recommended maintenance (oil change).
  static DateTime? predictNextMaintenanceDate(Vehicle vehicle, List<Intervention> history) {
    final avgKmPerDay = calculateAverageDailyKm(vehicle, history);
    final kmRemaining = vehicle.kilometrageProchVidange - vehicle.kilometrageActuel;

    if (kmRemaining <= 0) return DateTime.now();

    final daysRemaining = (kmRemaining / avgKmPerDay).round();
    return DateTime.now().add(Duration(days: daysRemaining));
  }

  /// Returns a health percentage based on predicted remaining life.
  static double calculateDynamicHealth(Vehicle vehicle, List<Intervention> history) {
    // Assuming 10k interval for generic health calculation if not specified
    const int standardInterval = 10000;
    final kmRemaining = vehicle.kilometrageProchVidange - vehicle.kilometrageActuel;
    
    if (kmRemaining <= 0) return 0.0;
    
    double health = (kmRemaining / standardInterval).clamp(0.0, 1.0);
    
    // Adjust health if usage is very high
    final avgDaily = calculateAverageDailyKm(vehicle, history);
    if (avgDaily > 100) {
      health *= 0.9; // High usage causes more wear
    }

    return health.clamp(0.0, 1.0);
  }
}
