import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/vehicle.dart';
import '../models/carnet_entretien.dart';

class AIService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<Map<String, dynamic>?> analyzeInvoice(Uint8List imageBytes) async {
    if (_apiKey.isEmpty) {
      print('AI Analysis error: Gemini API Key is missing in .env file');
      return null;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        requestOptions: const RequestOptions(apiVersion: 'v1'),
      );

      final prompt = [
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart("""
            You are an expert car invoice parser. Extract the following information from this invoice:
            - kilometrage (integer)
            - total_price (number)
            - items (list of objects with 'description', 'price', and 'category')
            
            Valid categories for items are: 'PIECE', 'FLUIDE', or 'SERVICE'.
            - 'PIECE': spare parts like filters, brake pads, tires, battery, etc.
            - 'FLUIDE': engine oil, coolant, etc.
            - 'SERVICE': labor cost, diagnostics, etc.

            Return ONLY a valid JSON object matching this structure:
            {
              "kilometrage": 120000,
              "total_price": 150.0,
              "items": [
                {"description": "Huile moteur 5W40", "price": 80.0, "category": "FLUIDE"},
                {"description": "Filtre à huile", "price": 20.0, "category": "PIECE"},
                {"description": "Main d'oeuvre", "price": 50.0, "category": "SERVICE"}
              ]
            }
            If a field is missing, use null or an empty list. Ensure categories are strictly 'PIECE', 'FLUIDE', or 'SERVICE'.
          """),
        ])
      ];

      final response = await model.generateContent(prompt);
      final text = response.text;
      
      if (text == null) return null;

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(text);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('AI Analysis error: $e');
      return null;
    }
  }

  static Future<String?> generateHealthReport({
    required Vehicle vehicle,
    required List<CarnetEntretien> history,
    required List<Uint8List> images,
  }) async {
    if (_apiKey.isEmpty) return "Erreur : Clé API manquante dans le fichier .env";

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        requestOptions: const RequestOptions(apiVersion: 'v1'),
      );

      final historyText = history.map((e) => 
        "- ${e.dateChangement.day}/${e.dateChangement.month}/${e.dateChangement.year}: ${e.nomComposantCustom} à ${e.dernierKilometrageChangement}km"
      ).join("\n");

      final promptParts = [
        Content.multi([
          TextPart("""
            Tu es un expert mécanicien virtuel spécialisé dans le diagnostic automobile. 
            Analyse l'état de santé général de ce véhicule en combinant son historique d'entretien et les photos fournies.

            Informations du véhicule :
            - Modèle : ${vehicle.marque} ${vehicle.modele}
            - Kilométrage actuel : ${vehicle.kilometrageActuel} km
            
            Historique des entretiens récents enregistrés dans l'application :
            $historyText
            
            Instructions pour ton analyse :
            1. Analyse visuellement les photos fournies (moteur, pneus, carrosserie, habitacle, tableau de bord, etc.) pour détecter des fuites, de la corrosion, de l'usure excessive ou des voyants allumés.
            2. Compare ces observations avec l'historique d'entretien pour voir si des entretiens critiques manquent par rapport au kilométrage.
            3. Génère un rapport de santé détaillé et pédagogique en français comprenant :
               - **Évaluation Globale** (Note sur 10)
               - **Analyse Visuelle** (Ce que tu observes précisément sur les photos)
               - **Analyse de l'Entretien** (Points forts de l'historique et ce qui semble oublié)
               - **Recommandations Immédiates** (Actions à faire d'urgence)
               - **Conseils de Maintenance Préventive** (Pour les 12 prochains mois ou 15 000 km)
            
            Utilise un ton professionnel, honnête et rassurant. Utilise le format Markdown pour structurer ta réponse.
          """),
          ...images.map((img) => DataPart('image/jpeg', img)),
        ])
      ];

      final response = await model.generateContent(promptParts);
      return response.text;
    } catch (e) {
      print('AI Health Report error: $e');
      return "Désolé, une erreur est survenue lors de la génération du rapport : $e";
    }
  }
}
