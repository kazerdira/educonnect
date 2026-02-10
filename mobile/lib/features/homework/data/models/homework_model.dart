import 'package:educonnect/features/homework/domain/entities/homework.dart';

class HomeworkModel extends Homework {
  const HomeworkModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    required super.courseId,
    required super.courseName,
    required super.title,
    required super.description,
    required super.instructions,
    required super.dueDate,
    required super.maxScore,
    super.attachmentUrl,
    required super.status,
    required super.submissionCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory HomeworkModel.fromJson(Map<String, dynamic> json) {
    return HomeworkModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      teacherName: json['teacher_name'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      courseName: json['course_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? '',
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0,
      attachmentUrl: json['attachment_url'] as String?,
      status: json['status'] as String? ?? '',
      submissionCount: (json['submission_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'course_id': courseId,
      'course_name': courseName,
      'title': title,
      'description': description,
      'instructions': instructions,
      'due_date': dueDate,
      'max_score': maxScore,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'status': status,
      'submission_count': submissionCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SubmissionModel extends Submission {
  const SubmissionModel({
    required super.id,
    required super.homeworkId,
    required super.studentId,
    required super.studentName,
    required super.content,
    super.attachmentUrl,
    super.grade,
    super.feedback,
    required super.status,
    required super.submittedAt,
    super.gradedAt,
    required super.updatedAt,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    return SubmissionModel(
      id: json['id'] as String? ?? '',
      homeworkId: json['homework_id'] as String? ?? '',
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      attachmentUrl: json['attachment_url'] as String?,
      grade: (json['grade'] as num?)?.toDouble(),
      feedback: json['feedback'] as String?,
      status: json['status'] as String? ?? '',
      submittedAt: json['submitted_at'] as String? ?? '',
      gradedAt: json['graded_at'] as String?,
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homework_id': homeworkId,
      'student_id': studentId,
      'student_name': studentName,
      'content': content,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (grade != null) 'grade': grade,
      if (feedback != null) 'feedback': feedback,
      'status': status,
      'submitted_at': submittedAt,
      if (gradedAt != null) 'graded_at': gradedAt,
      'updated_at': updatedAt,
    };
  }
}
