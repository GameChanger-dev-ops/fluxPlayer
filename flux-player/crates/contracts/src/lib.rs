pub trait LibraryService {
    fn scan_folder(&self, path: &str) -> Result<u64, String>;
    fn list_media(&self) -> Result<Vec<domain::MediaRow>, String>;
}

pub trait PlaybackService {
    fn save_progress(&self, id: i64, position: f64, duration: f64) -> Result<(), String>;
}
