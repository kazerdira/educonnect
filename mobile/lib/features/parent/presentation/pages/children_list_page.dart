import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:educonnect/features/parent/domain/entities/child.dart' as ent;
import 'package:educonnect/features/parent/presentation/bloc/parent_bloc.dart';

class ChildrenListPage extends StatefulWidget {
  const ChildrenListPage({super.key});

  @override
  State<ChildrenListPage> createState() => _ChildrenListPageState();
}

class _ChildrenListPageState extends State<ChildrenListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ParentBloc>().add(ChildrenListRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes enfants')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'children_list_fab',
        onPressed: () => context.push('/parent/children/add'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<ParentBloc>().add(ChildrenListRequested());
        },
        child: BlocConsumer<ParentBloc, ParentState>(
          listener: (context, state) {
            if (state is ChildDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enfant supprimé')),
              );
              context.read<ParentBloc>().add(ChildrenListRequested());
            }
          },
          builder: (context, state) {
            if (state is ParentLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ParentError) {
              return Center(child: Text(state.message));
            }

            if (state is ChildrenLoaded) {
              if (state.children.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.child_care,
                          size: 64.sp, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text('Aucun enfant ajouté',
                          style: TextStyle(
                              fontSize: 16.sp, color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: state.children.length,
                itemBuilder: (context, index) =>
                    _childCard(state.children[index], theme),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _childCard(ent.Child child, ThemeData theme) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            '${child.firstName[0]}${child.lastName[0]}'.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text('${child.firstName} ${child.lastName}'),
        subtitle: Text(
          [child.levelName, child.cycle, child.school]
              .where((s) => s != null && s.isNotEmpty)
              .join(' • '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              context.push('/parent/children/${child.id}/edit', extra: child);
            } else if (v == 'progress') {
              context.push('/parent/children/${child.id}/progress');
            } else if (v == 'delete') {
              _confirmDelete(child);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
            const PopupMenuItem(value: 'progress', child: Text('Progression')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ent.Child child) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
            'Supprimer ${child.firstName} ${child.lastName} de votre liste ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              context
                  .read<ParentBloc>()
                  .add(DeleteChildRequested(childId: child.id));
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
