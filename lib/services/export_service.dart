import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExportService {
  /// Demande les permissions de stockage
  static Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted) return true;
      
      // Pour Android 11+
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }
    return true; // iOS
  }

  /// Exporte les données en Excel
  static Future<String?> exportToExcel(List<Map<String, dynamic>> data) async {
    if (!await _requestPermissions()) return null;

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Interventions'];
      excel.setDefaultSheet('Interventions');

      // Header
      sheetObject.appendRow([
        'ID',
        'Titre',
        'Statut',
        'Date',
        'Prix (DT)',
        'Payé',
        'ID Mécanicien'
      ]);

      // Data
      for (var item in data) {
        sheetObject.appendRow([
          item['id'].toString(),
          item['titre'].toString(),
          item['statut'].toString(),
          item['date'].toString(),
          double.tryParse(item['prixEstime'].toString()) ?? 0.0,
          item['estPaye'] ? 'Oui' : 'Non',
          item['mecanicienId'].toString(),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        if (kIsWeb) {
          throw Exception("L'export Excel direct n'est pas encore supporté sur la version Web. Veuillez utiliser l'export PDF.");
        }
        
        final directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/rapport_interventions_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return filePath;
      }
    } catch (e) {
      print('Erreur Export Excel: $e');
    }
    return null;
  }

  /// Exporte les données en PDF
  static Future<String?> exportToPdf(List<Map<String, dynamic>> data) async {
    if (!await _requestPermissions()) return null;

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Rapport des Interventions VroomLog', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Titre', 'Statut', 'Date', 'Prix (DT)', 'Payé'],
                data: data.map((item) {
                  return [
                    item['titre'].toString(),
                    item['statut'].toString(),
                    item['date'].toString().split('T').first,
                    item['prixEstime'].toString(),
                    item['estPaye'] ? 'Oui' : 'Non',
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: 'rapport_vroomlog_${DateTime.now().millisecondsSinceEpoch}.pdf');
        return "web_success";
      }

      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/rapport_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      print('Erreur Export PDF: $e');
    }
    return null;
  }
}
