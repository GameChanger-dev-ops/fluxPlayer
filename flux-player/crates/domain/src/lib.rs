use serde::Serialize;

#[derive(Serialize, Clone)]
pub struct MediaRow {
    pub id: i64,
    pub path: String,
    pub title: String,
    pub ext: String,
    pub size: i64,
    pub position: f64,
    pub duration: f64,
}
