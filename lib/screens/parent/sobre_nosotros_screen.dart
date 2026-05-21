import 'package:flutter/material.dart';
import '/widgets/parent/sobre_nosotros_body.dart';

class SobreNosotrosScreen extends StatefulWidget {
  final String parentEmail;
  final String userName;
  final String userId;

  const SobreNosotrosScreen({
    super.key,
    required this.parentEmail,
    required this.userName,
    required this.userId,
  });

  @override
  State<SobreNosotrosScreen> createState() => _SobreNosotrosScreenState();
}

class _SobreNosotrosScreenState extends State<SobreNosotrosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SobreNosotrosBody();
  }
}
