import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _specialiteController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _selectedRole = 'user'; // 'user' ou 'mecanicien'

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _specialiteController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final nom = _nomController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final specialite = _specialiteController.text.trim();
    final telephone = _telephoneController.text.trim();

    // Validations
    if (nom.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Veuillez remplir tous les champs obligatoires');
      return;
    }

    if (_selectedRole == 'mecanicien' &&
        (specialite.isEmpty || telephone.isEmpty)) {
      _showSnack('Veuillez remplir votre spécialité et téléphone');
      return;
    }

    if (password != confirm) {
      _showSnack('Les mots de passe ne correspondent pas');
      return;
    }

    if (password.length < 6) {
      _showSnack('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.register(
        email: email,
        password: password,
        nom: nom,
        role: _selectedRole,
        specialite: _selectedRole == 'mecanicien' ? specialite : null,
        telephone: _selectedRole == 'mecanicien' ? telephone : null,
      );

      if (mounted) {
        if (_selectedRole == 'mecanicien') {
          // Mécanicien → attente approbation
          _showApprovalDialog();
        } else {
          // User → directement au login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pending_actions_rounded,
                    color: Colors.orange, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Compte en attente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Votre compte mécanicien a été créé avec succès.\n\n'
                'Il est maintenant en attente d\'approbation par l\'administrateur. '
                'Vous serez notifié une fois votre compte validé.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // fermer dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Compris',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car_outlined,
                          size: 32, color: Color(0xFF1976D2)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Vroom Log',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Créer un compte',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Sélecteur de rôle ──────────────────────────────────────────
              const Text('Je suis...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _RoleChip(
                    label: 'Utilisateur',
                    icon: Icons.person_outline,
                    isSelected: _selectedRole == 'user',
                    onTap: () => setState(() => _selectedRole = 'user'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _RoleChip(
                    label: 'Mécanicien',
                    icon: Icons.handyman_outlined,
                    isSelected: _selectedRole == 'mecanicien',
                    onTap: () => setState(() => _selectedRole = 'mecanicien'),
                  )),
                ],
              ),

              // Info mécanicien
              if (_selectedRole == 'mecanicien') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Votre compte sera validé par un administrateur avant activation.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Champs communs ─────────────────────────────────────────────
              _buildTextField(
                  'Nom complet *', _nomController, Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField('Email *', _emailController, Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),

              // ── Champs mécanicien uniquement ───────────────────────────────
              if (_selectedRole == 'mecanicien') ...[
                _buildTextField(
                  'Spécialité * (ex: Vidange, Freins, Climatisation)',
                  _specialiteController,
                  Icons.build_outlined,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Téléphone *',
                  _telephoneController,
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
              ],

              // ── Mots de passe ──────────────────────────────────────────────
              _buildPasswordField(
                'Mot de passe *',
                _passwordController,
                _obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                'Confirmer le mot de passe *',
                _confirmPasswordController,
                _obscureConfirmPassword,
                () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),

              const SizedBox(height: 32),

              // ── Bouton s'enregistrer ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("S'enregistrer",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),

              // ── Lien vers login ────────────────────────────────────────────
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Déjà un compte ? ',
                        style: TextStyle(color: Colors.grey.shade600)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.grey),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1976D2), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.grey),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1976D2), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }
}

// ── Widget rôle chip ──────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1976D2) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
