import 'package:flutter/material.dart';
import '../auth/role_selection_screen.dart';
import '../../widgets/parent/parent_terms_body.dart';


class ParentTermsScreen extends StatefulWidget {
  final String parentEmail;
  final String userName;
  final String userId;

  const ParentTermsScreen({
    super.key,
    required this.parentEmail,
    required this.userName,
    required this.userId,
  });

  @override
  State<ParentTermsScreen> createState() => _ParentTermsScreenState();
}


class _ParentTermsScreenState extends State<ParentTermsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ParentTermsBody(
      userName: widget.userName,
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
    );
  }
}