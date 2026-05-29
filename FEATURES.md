# Fonctionnalités de l'Application VroomLog

Cette application est une solution complète de gestion d'entretien automobile connectant les propriétaires de véhicules et les mécaniciens, propulsée par l'intelligence artificielle.

---

## 🚗 Pour les Utilisateurs (Propriétaires de véhicules)

### 1. Gestion des Véhicules
*   **Ajout et Modification** : Enregistrer plusieurs véhicules avec marque, modèle et immatriculation.
*   **Photos de Profil** : Télécharger jusqu'à 3 photos permanentes par véhicule pour faciliter l'identification.
*   **Suivi du Kilométrage** : Mise à jour manuelle ou automatique via un service de suivi GPS en arrière-plan.

### 2. Maintenance Prédictive & IA
*   **Bilan de Santé IA** : Analyse intelligente combinant l'historique d'entretien et jusqu'à 10 photos (moteur, pneus, etc.) pour générer un rapport de santé détaillé via Gemini 1.5 Flash.
*   **Alertes de Vidange** : Calcul automatique de l'urgence des vidanges basé sur l'usage quotidien réel.
*   **Journal d'Entretien (Carnet)** : Suivi précis de chaque composant (pneus, freins, batterie) avec calcul d'usure.

### 3. Prise de Rendez-vous & Interventions
*   **Formulaire d'Intervention** : Créer des demandes ciblées (pièces, fluides, contrôles).
*   **Photos de Mission** : Envoyer des photos spécifiques d'une panne ou d'un bruit suspect lors de la demande.
*   **Sélection du Mécanicien** : Choisir un mécanicien sur une carte ou via une liste filtrée par spécialité.
*   **Planning en Temps Réel** : Choisir des créneaux horaires disponibles selon les horaires d'ouverture du garage.

### 4. Communication & Historique
*   **Chat Intégré** : Discuter en temps réel avec le mécanicien une fois l'intervention acceptée.
*   **Historique Unifié** : Consulter toutes les interventions passées et les factures associées.
*   **Notifications** : Recevoir des alertes pour les rendez-vous acceptés, les véhicules prêts ou les rappels de sécurité.

---

## 🔧 Pour les Mécaniciens

### 1. Gestion du Garage
*   **Profil Professionnel** : Renseigner le nom du garage, la spécialité, le téléphone et la localisation précise sur une carte OpenStreetMap.
*   **Statut de Disponibilité** : Basculer entre "Disponible" et "Occupé" pour contrôler le flux de clients.

### 2. Tableau de Bord & Analytics
*   **Vue d'Ensemble** : Statistiques sur le nombre d'interventions terminées, en cours et les demandes en attente.
*   **Graphiques de Revenus** : Suivi financier des gains sur différentes périodes (jour, semaine, mois, année).
*   **Calendrier des Missions** : Gestion visuelle des rendez-vous par jour.

### 3. Exécution des Interventions
*   **Détails de Mission complets** : Accès aux photos du véhicule et aux photos spécifiques envoyées par le client.
*   **Scan de Facture par IA** : Extraire automatiquement le prix, le kilométrage et les articles depuis une photo de facture papier.
*   **Mise à jour Automatique** : La validation d'une facture met à jour automatiquement le kilométrage du client et réinitialise l'usure des composants concernés.

### 4. Communication Client
*   **Messagerie Instantanée** : Clarifier les besoins avec le client via le chat.
*   **Notifications Push** : Alerter instantanément le client de l'avancement des travaux.

---

## 🛡️ Pour les Administrateurs (Dashboard Admin)

*   **Validation des Comptes** : Examiner et approuver les nouveaux mécaniciens (vérification du statut "en révision").
*   **Gestion du Référentiel** : Administrer la liste des composants standards et leurs seuils de maintenance par défaut.
*   **Surveillance** : Vue globale sur l'activité de la plateforme.

---

## 🤖 Fonctionnalités Transverses IA (Gemini 2.5 Flash)
1.  **Analyse de Facture** : Parsing OCR intelligent des documents papier.
2.  **Diagnostic de Santé** : Corrélation entre données textuelles (historique) et données visuelles (photos) pour un conseil d'expert virtuel.
3.  **Algorithme de Prédiction** : Estimation de la date de la prochaine maintenance basée sur le comportement de conduite de l'utilisateur.
