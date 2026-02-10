import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:educonnect/features/admin/domain/entities/admin.dart';
import 'package:educonnect/features/admin/presentation/bloc/admin_bloc.dart';

class AdminSubjectsPage extends StatefulWidget {
  const AdminSubjectsPage({super.key});

  @override
  State<AdminSubjectsPage> createState() => _AdminSubjectsPageState();
}

class _AdminSubjectsPageState extends State<AdminSubjectsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Subject> _subjects = [];
  List<Level> _levels = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matières & Niveaux'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Matières'),
            Tab(text: 'Niveaux'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_subjects_fab',
        onPressed: () {
          if (_tabController.index == 0) {
            _showSubjectDialog();
          } else {
            _showLevelDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: BlocListener<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminSubjectsUpdated) {
            setState(() => _subjects = state.subjects);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Matières mises à jour')),
            );
          }
          if (state is AdminLevelsUpdated) {
            setState(() => _levels = state.levels);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Niveaux mis à jour')),
            );
          }
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSubjectsList(),
            _buildLevelsList(),
          ],
        ),
      ),
    );
  }

  // ── Subjects tab ────────────────────────────────────────────

  Widget _buildSubjectsList() {
    if (_subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.book_outlined, size: 64.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text('Aucune matière ajoutée',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey[500])),
            SizedBox(height: 8.h),
            const Text('Appuyez sur + pour ajouter'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _subjects.length,
      itemBuilder: (_, i) {
        final s = _subjects[i];
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.withOpacity(0.1),
              child: Text(s.code,
                  style: TextStyle(fontSize: 11.sp, color: Colors.indigo)),
            ),
            title: Text(s.nameFr),
            subtitle: Text(s.nameAr),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() => _subjects.removeAt(i));
              },
            ),
          ),
        );
      },
    );
  }

  // ── Levels tab ──────────────────────────────────────────────

  Widget _buildLevelsList() {
    if (_levels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stairs_outlined, size: 64.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text('Aucun niveau ajouté',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey[500])),
            SizedBox(height: 8.h),
            const Text('Appuyez sur + pour ajouter'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _levels.length,
      itemBuilder: (_, i) {
        final l = _levels[i];
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.teal.withOpacity(0.1),
              child: Text(l.code,
                  style: TextStyle(fontSize: 11.sp, color: Colors.teal)),
            ),
            title: Text(l.nameFr),
            subtitle: Text('${l.nameAr}  •  ${l.cycle}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                setState(() => _levels.removeAt(i));
              },
            ),
          ),
        );
      },
    );
  }

  // ── Save helpers ────────────────────────────────────────────

  void _saveSubjects() {
    context
        .read<AdminBloc>()
        .add(AdminUpdateSubjectsRequested(subjects: _subjects));
  }

  void _saveLevels() {
    context.read<AdminBloc>().add(AdminUpdateLevelsRequested(levels: _levels));
  }

  // ── Dialogs ─────────────────────────────────────────────────

  void _showSubjectDialog() {
    final nameArCtrl = TextEditingController();
    final nameFrCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter une matière'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameFrCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nom (FR)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: nameArCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nom (AR)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Code', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (nameFrCtrl.text.trim().isEmpty ||
                  codeCtrl.text.trim().isEmpty) return;
              setState(() {
                _subjects.add(Subject(
                  nameAr: nameArCtrl.text.trim(),
                  nameFr: nameFrCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                ));
              });
              Navigator.pop(ctx);
              _saveSubjects();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showLevelDialog() {
    final nameArCtrl = TextEditingController();
    final nameFrCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final cycleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un niveau'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameFrCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nom (FR)', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: nameArCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nom (AR)', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Code', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: cycleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Cycle (primaire, moyen, secondaire)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (nameFrCtrl.text.trim().isEmpty ||
                  codeCtrl.text.trim().isEmpty ||
                  cycleCtrl.text.trim().isEmpty) return;
              setState(() {
                _levels.add(Level(
                  nameAr: nameArCtrl.text.trim(),
                  nameFr: nameFrCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  cycle: cycleCtrl.text.trim(),
                ));
              });
              Navigator.pop(ctx);
              _saveLevels();
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
