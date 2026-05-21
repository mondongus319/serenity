import 'package:flutter/material.dart';
import 'content_selection_screen.dart';
import '../../widgets/parent/child_detail_body.dart';

class ChildDetailScreen extends StatelessWidget {
  final String idNino;
  final String nombreNino;
  final String parentEmail;
  final String userName;
  final String userId;

  const ChildDetailScreen({
    super.key,
    required this.idNino,
    required this.nombreNino,
    required this.parentEmail,
    required this.userName,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ChildDetailBody(
      nombreNino: nombreNino,
      onBack: () => Navigator.pop(context),
      onYoutube: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContentSelectionScreen(
            idNino:    idNino,
            nombreNino: nombreNino,
            padreId:   userId,
          ),
        ),
      ),
    );
  }
}
