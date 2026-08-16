#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod db; mod scanner;
use db::{AppDb,MediaRow};
use tauri::{Manager,State};
use tauri_plugin_dialog::DialogExt;
use std::path::PathBuf;

#[tauri::command]
fn media_list(db:State<'_,AppDb>)->Result<Vec<MediaRow>,String>{db::list_media(&db).map_err(|e|e.to_string())}

#[tauri::command]
async fn choose_folder(app:tauri::AppHandle)->Result<Option<String>,String>
{Ok(app.dialog().file().blocking_pick_folder().map(|p|p.to_string()))}

#[tauri::command]
fn scan_folder(db:State<'_,AppDb>,path:String)->Result<u64,String>{scanner::scan(&db,&path)}

#[tauri::command]
fn save_progress(db:State<'_,AppDb>,id:i64,position:f64,duration:f64)->Result<(),String>
{db::save_position(&db,id,position,duration).map(|_|()).map_err(|e|e.to_string())}

#[tauri::command]
fn app_info()->serde_json::Value{serde_json::json!({"name":"Flux Player","phase":"vertical-slice-1","playback":"browser adapter pending libmpv spike"})}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run(){
 tauri::Builder::default()
 .plugin(tauri_plugin_dialog::init())
 .plugin(tauri_plugin_fs::init())
 .setup(|app|{let dir=app.path().app_data_dir().unwrap_or(PathBuf::from(".flux-data"));std::fs::create_dir_all(&dir).unwrap();app.manage(db::open(dir.join("flux.sqlite")).expect("database init failed"));Ok(())})
 .invoke_handler(tauri::generate_handler![media_list,choose_folder,scan_folder,save_progress,app_info])
 .run(tauri::generate_context!()).expect("error while running Flux Player");
}

fn main(){run();}
