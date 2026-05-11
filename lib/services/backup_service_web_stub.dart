// Web stub for dart:io used by backup_service.dart.
// On web, backup/restore early-returns before any File usage,
// but the compiler still needs the types to resolve.

class File {
  final String path;
  File(this.path);
  
  Future<bool> exists() async => false;
  Future<List<int>> readAsBytes() async => [];
  Future<File> writeAsBytes(List<int> bytes) async => this;
  
  Directory get parent => Directory(path);
}

class Directory {
  final String path;
  Directory(this.path);
  
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
}
