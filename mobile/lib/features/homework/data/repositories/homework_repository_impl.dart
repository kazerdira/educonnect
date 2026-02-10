import 'package:educonnect/features/homework/data/datasources/homework_remote_datasource.dart';
import 'package:educonnect/features/homework/domain/entities/homework.dart';
import 'package:educonnect/features/homework/domain/repositories/homework_repository.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  final HomeworkRemoteDataSource remoteDataSource;

  HomeworkRepositoryImpl({required this.remoteDataSource});

  @override
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
  }) =>
      remoteDataSource.createHomework(
        courseId: courseId,
        title: title,
        description: description,
        instructions: instructions,
        dueDate: dueDate,
        maxScore: maxScore,
        attachmentUrl: attachmentUrl,
        status: status,
        chapterId: chapterId,
      );

  @override
  Future<List<Homework>> listHomework() => remoteDataSource.listHomework();

  @override
  Future<Homework> getHomework(String id) => remoteDataSource.getHomework(id);

  @override
  Future<Submission> submitHomework(
    String homeworkId, {
    required String content,
    String? attachmentUrl,
  }) =>
      remoteDataSource.submitHomework(
        homeworkId,
        content: content,
        attachmentUrl: attachmentUrl,
      );

  @override
  Future<Submission> gradeHomework(
    String homeworkId, {
    required double grade,
    String? feedback,
    required String status,
  }) =>
      remoteDataSource.gradeHomework(
        homeworkId,
        grade: grade,
        feedback: feedback,
        status: status,
      );
}
