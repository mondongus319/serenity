import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../servicces/firestore_service.dart';
import '../../widgets/parent/parent_verification_body.dart';

class ParentVerificationScreen extends StatefulWidget {
  final String email;
  final String userName;
  final String userId;

  const ParentVerificationScreen({
    super.key,
    required this.email,
    required this.userName,
    required this.userId,
  });

  @override
  State<ParentVerificationScreen> createState() =>
      _ParentVerificationScreenState();
}

class _ParentVerificationScreenState
    extends State<ParentVerificationScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final MobileScannerController _cameraController = MobileScannerController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ParentVerificationBody(
      codigoController: _codigoController,
      cameraController: _cameraController,
      isLoading: _isLoading,
      onBack: () => Navigator.pop(context),
      onVerificar: _verificarCodigo,
      onEscanear: _abrirEscaner,
    );
  }

  void _abrirEscaner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: const Color(0xFF06B6D4).withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8).withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded,
                        color: Color(0xFF06B6D4), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Escanear Código QR',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F172A),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.3),
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFF06B6D4), size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _cameraController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final code = barcodes.first.rawValue;
                            if (code != null && code.isNotEmpty) {
                              Navigator.pop(context);
                              setState(
                                  () => _codigoController.text = code);
                              _verificarCodigo();
                            }
                          }
                        },
                      ),
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF06B6D4)
                                  .withOpacity(0.8),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verificarCodigo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un código'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resultado = await FirestoreService.vincularNinoPadre(
        padreId: widget.userId,
        codigoVinculacion: codigo,
      );

      setState(() => _isLoading = false);

      if (resultado['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Niño vinculado exitosamente!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message'] ?? 'Código inválido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _codigoController.dispose();
    super.dispose();
  }
}
