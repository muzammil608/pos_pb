import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    _db = await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), 'pos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders(
            id TEXT PRIMARY KEY,
            data TEXT
          )
        ''');
      },
    );
  }
}
