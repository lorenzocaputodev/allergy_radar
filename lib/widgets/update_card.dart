import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/update_checker.dart';
import '../state/update_state.dart';
import '../theme/palette.dart';

class UpdateCard extends StatelessWidget {
  const UpdateCard({required this.version, super.key});

  final String version;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        color: p.pineSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => openRelease(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: p.pine, shape: BoxShape.circle),
                  child: Icon(Icons.system_update_alt, color: p.onPine),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'È disponibile la versione $version',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text('Tocca per scaricarla da GitHub', style: TextStyle(fontSize: 13, color: p.ink2)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Più tardi',
                  icon: Icon(Icons.close, color: p.ink2),
                  onPressed: context.read<UpdateState>().dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openRelease(BuildContext context) async {
  if (await UpdateChecker.openReleasePage() || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Non riesco ad aprire il browser.')));
}
