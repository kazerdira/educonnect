import 'package:educonnect/features/homework/domain/entities/homework.dart';

abstract class HomeworkRepository {
  Future<Homework> createHomework({
    required String courseId,
    required String title,
    required String description,
    required String instructions,
    required String dueDate,
    required double maxScore,
    String? attachmentUrl,
    required String status,
    String? chapterId,
  });

  Future<List<Homework>> listHomework();
  Future<Homework> getHomework(String id);

  Future<Submission> submitHomework(
    String homeworkId, {
    required String content,
    String? attachmentUrl,
  });

  Future<Submission> gradeHomework(
    String homeworkId, {
    required double grade,
    String? feedback,
    required String status,
  });
}
