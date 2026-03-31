import 'package:flutter/material.dart';
import '../../core/theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Impact',
            style: Theme.of(context).textTheme.headlineMedium),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Massive Gamification Gauge
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 240,
                      height: 240,
                      child: CircularProgressIndicator(
                        value: 0.65,
                        strokeWidth: 8, // 8px stroke as designed
                        backgroundColor: SwipifyTheme.surfaceContainerHighest,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(SwipifyTheme.primary),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '1.2',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                  fontSize: 64, color: SwipifyTheme.primary),
                        ),
                        Text(
                          'GB SAVED',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Action Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                      context, 'Photos Deleted', '342', SwipifyTheme.secondary),
                  _buildStatCard(
                      context, 'Videos Deleted', '18', SwipifyTheme.secondary),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                      context, 'Batches Reviewed', '4', SwipifyTheme.primary),
                  _buildStatCard(
                      context, 'Time Saved', '2h', SwipifyTheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, String label, String value, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SwipifyTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
