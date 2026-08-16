use rusqlite::{Connection, params};
use std::{path::PathBuf, sync::Mutex};
use domain::MediaRow;

pub struct AppDb(pub Mutex<Connection>);

pub fn open(path: PathBuf) -> rusqlite::Result<AppDb> {
 let conn=Connection::open(path)?;
 conn.pragma_update(None,"journal_mode","WAL")?;
 conn.execute_batch(r#"
 PRAGMA foreign_keys=ON;
 CREATE TABLE IF NOT EXISTS profiles(id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
 CREATE TABLE IF NOT EXISTS media_files(id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, title TEXT NOT NULL, ext TEXT NOT NULL, size INTEGER NOT NULL, modified INTEGER NOT NULL, position REAL NOT NULL DEFAULT 0, duration REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
 CREATE INDEX IF NOT EXISTS idx_media_title ON media_files(title);
 INSERT OR IGNORE INTO profiles(id,name) VALUES(1,'Main profile');
 "#)?;
 Ok(AppDb(Mutex::new(conn)))
}

pub fn list_media(db:&AppDb)->rusqlite::Result<Vec<MediaRow>>{
 let c=db.0.lock().unwrap(); let mut st=c.prepare("SELECT id,path,title,ext,size,position,duration FROM media_files ORDER BY title COLLATE NOCASE")?;
 let rows=st.query_map([],|r|Ok(MediaRow{id:r.get(0)?,path:r.get(1)?,title:r.get(2)?,ext:r.get(3)?,size:r.get(4)?,position:r.get(5)?,duration:r.get(6)?}))?;
 rows.collect()
}

pub fn upsert_media(db:&AppDb,path:&str,title:&str,ext:&str,size:i64,modified:i64)->rusqlite::Result<usize>{
 let c=db.0.lock().unwrap(); c.execute("INSERT INTO media_files(path,title,ext,size,modified) VALUES(?1,?2,?3,?4,?5) ON CONFLICT(path) DO UPDATE SET title=excluded.title,ext=excluded.ext,size=excluded.size,modified=excluded.modified",params![path,title,ext,size,modified])
}

pub fn save_position(db:&AppDb,id:i64,position:f64,duration:f64)->rusqlite::Result<usize>{
 let c=db.0.lock().unwrap(); c.execute("UPDATE media_files SET position=?1,duration=?2 WHERE id=?3",params![position,duration,id])
}
