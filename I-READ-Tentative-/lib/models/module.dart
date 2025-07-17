import 'package:i_read_app/models/materials.dart';
import 'package:i_read_app/models/question.dart';

class Module {
  String id;
  String title;
  String description;
  String difficulty;
  String category;
  String slug;
  String createdBy;
  DateTime createdAt;
  DateTime? updatedAt;
  List<Question> questionsPerModule;
  List<ModuleMaterial> materials;
  bool isLocked;
  int completed = 0;
  String fileUrl;
  Module({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.category,
    required this.slug,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    required this.questionsPerModule,
    required this.materials,
    required this.isLocked,
    required this.completed,
    required this.fileUrl,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      difficulty: json['difficulty'] ?? 'Easy',
      category: json['category'] ?? 'Uncategorized',
      slug: json['slug'] ?? '',
      createdBy: json['created_by'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      questionsPerModule: json['questions_per_module'] != null
          ? (json['questions_per_module'] as List)
              .map((q) => Question.fromJson(q))
              .toList()
          : [],
      materials: json['materials'] != null
          ? (json['materials'] as List)
              .map((m) => ModuleMaterial.fromJson(m))
              .toList()
          : [],
      isLocked: json['isLock'] ?? false,
      completed: json['completed'] ?? 0,
      fileUrl: json['file_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'category': category,
      'slug': slug,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'questions_per_module': questionsPerModule.map((q) => q.toJson()).toList(),
      'isLock': isLocked,
      'completed': completed,
      'file_url': fileUrl,
      'materials': materials.map((m) => m.toJson()).toList(),
    };
  }
}
