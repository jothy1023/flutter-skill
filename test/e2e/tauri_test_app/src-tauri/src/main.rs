#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    // Build a Tokio runtime for the flutter-skill bridge
    let rt = tokio::runtime::Runtime::new().expect("Failed to create Tokio runtime");
    let _guard = rt.enter();

    tauri::Builder::default()
        .plugin(tauri_plugin_flutter_skill::init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
