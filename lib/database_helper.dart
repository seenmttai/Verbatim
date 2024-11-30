import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

//Sql management file.

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> database() async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'my_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await createSubjectTable();
  }


  Future<void> createSubjectTable() async {
    try {
      final db = await database();
        await db.execute('''
          CREATE TABLE SubjectList (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            Name TEXT,
            Desc TEXT,
            Img TEXT
          )
        ''');
      } catch (e) {
        print('Error creating SubjectList table: $e');
        // Consider more robust error handling, like showing a user-friendly message.
      }
  }

    Future<bool> databaseExists() async {
    String path = join(await getDatabasesPath(), 'my_database.db');
    return await File(path).exists();
  }

  Future<bool> ifEmpty(tableName) async{
    final db=await database();
    final count= Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM $tableName") 
    );
    return count==0;
  }


  Future<void> createTableInCurrentDataBase(String tableName, List<String> columns) async {
    final db = await database();
    String columnDefinitions = columns.map((col) => '$col TEXT').join(', ');
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnDefinitions
        )
      ''');
    } catch (e) {
      print("Error creating table $tableName: $e");
    }
  }

  Future<int> insertRow(String tableName, Map<String, dynamic> values) async {
    final db = await database();
    try {
      return await db.insert(tableName, values);
      } catch (e) {
      print('Error inserting row into $tableName: $e');
      return 0; // Indicate failure
    }
  }

  Future<List<Map<String, dynamic>>> readAll(String table) async {
    final db = await database();
      try {
      return await db.query(table);
    } catch (e) {
      print('Error reading all rows from $table: $e');
      return []; // Return empty list in case of error
    }
  }

  Future<void> deleteRowById(String table, int id) async {
    final db = await database();
    try {
      await db.delete(
        table,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting row from $table: $e');
    }
  }

  Future<int> updateRow(String table, int id, Map<String, dynamic> values) async {
    final db = await database();
    try {
      return await db.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
     } catch (e) {
      print('Error updating row in $table: $e');
       return 0;
    }
  }

  Future<bool> tableExists(String tableName) async {
    final db = await database();
    try {
      final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'");
      return result.isNotEmpty;
     } catch (e) {
      print('Error checking if table $tableName exists: $e');
      return false;
    }
  }
}