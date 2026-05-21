import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubePlayerScreen extends StatefulWidget {
  final String videoId;
  final String titulo;

  const YoutubePlayerScreen({
    super.key,
    required this.videoId,
    required this.titulo,
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController controller;

  static const bgPrimary = Color(0xFF0F172A);
  static const bgCard    = Color(0xFF1E293B);
  static const accentCyan = Color(0xFF06B6D4);
  static const textPearl  = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        enableCaption: false,
        controlsVisibleAtStart: true,
        useHybridComposition: true,
        forceHD: false,
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: accentCyan,
        progressColors: const ProgressBarColors(
          playedColor: accentCyan,
          handleColor: accentCyan,
        ),
      ),
      builder: (context, player) => Scaffold(
        backgroundColor: bgPrimary,
        appBar: AppBar(
          backgroundColor: bgCard,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: accentCyan),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPearl,
            ),
          ),
        ),
        body: player,
      ),
    );
  }
}