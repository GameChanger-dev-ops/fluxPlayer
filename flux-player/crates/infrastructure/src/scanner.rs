use std::{path::Path,fs};
use walkdir::WalkDir;
use crate::db::{AppDb,upsert_media};

const EXT:&[&str]= &["mp4","mkv","webm","mov","avi","m4v","ts"];

pub fn scan(db:&AppDb,root:&str)->Result<u64,String>{
 let p=Path::new(root); if !p.is_dir(){return Err("Folder does not exist or is not a directory".into())}
 let mut count=0;
 for entry in WalkDir::new(p).follow_links(false).into_iter().filter_map(Result::ok){
  let path=entry.path(); if !path.is_file(){continue}
  let ext=path.extension().and_then(|x|x.to_str()).unwrap_or("").to_lowercase();
  if !EXT.contains(&ext.as_str()){continue}
  let meta=fs::metadata(path).map_err(|e|e.to_string())?;
  let title=path.file_stem().and_then(|x|x.to_str()).unwrap_or("Untitled").replace(['.','_'],' ');
  let modified=meta.modified().ok().and_then(|t|t.duration_since(std::time::UNIX_EPOCH).ok()).map(|x|x.as_secs() as i64).unwrap_or(0);
  upsert_media(db,&path.to_string_lossy(),title.trim(),&ext,meta.len() as i64,modified).map_err(|e|e.to_string())?;
  count+=1;
 }
 Ok(count)
}
