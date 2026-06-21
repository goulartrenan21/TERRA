import 'package:flutter/material.dart';

class RunSummaryScreen extends StatelessWidget {
  final String activityId;
  const RunSummaryScreen({super.key, required this.activityId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Resumo da Corrida')),
    body: Center(child: Text('Atividade: $activityId — Fase 7')),
  );
}
