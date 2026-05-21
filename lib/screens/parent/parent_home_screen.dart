import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'parent_verification_screen.dart';
import '../auth/role_selection_screen.dart';
import 'child_detail_screen.dart';
import '../../providers/parent_provider.dart';
import '../../../../widgets/parent/parent_home_body.dart';

class ParentHomeScreen extends StatefulWidget {
  final String parentEmail;
  final String userName;
  final String userId;

  const ParentHomeScreen({
    super.key,
    required this.parentEmail,
    required this.userName,
    required this.userId,
  });

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ParentProvider>();
      provider.cargarNinos(widget.userId);
      provider.cargarDatos(
        widget.userId,
        emailFallback:  widget.parentEmail,
        nombreFallback: widget.userName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ParentProvider>(
      builder: (context, parent, _) {
        return ParentHomeBody(
          userName:        parent.nombre.isNotEmpty ? parent.nombre : widget.userName,
          ninos:           parent.ninos,
          isLoading:       parent.isLoadingNinos,
          onSwitchProfile: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RoleSelectionScreen(
                email:    widget.parentEmail,
                userName: widget.userName,
                userId:   widget.userId,
              ),
            ),
          ),
          onAddChild: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParentVerificationScreen(
                  email:    widget.parentEmail,
                  userName: widget.userName,
                  userId:   widget.userId,
                ),
              ),
            );
            if (!mounted) return;
            context.read<ParentProvider>().cargarNinos(widget.userId);
          },
          onTapChild: (nino) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChildDetailScreen(
                idNino:      nino['id'].toString(),       // ✅ FIX: 'id' en minúscula
                nombreNino:  nino['nombre'] ?? '',        // ✅ FIX: clave consistente
                parentEmail: widget.parentEmail,
                userName:    widget.userName,
                userId:      widget.userId,
              ),
            ),
          ),
        );
      },
    );
  }
}