mod cdp;
mod ops;
mod pool;
mod server;
mod workflow;

use pool::ConnectionPool;
use std::sync::Arc;

/// Find and launch Chrome for Testing with CDP enabled.
async fn launch_cft(port: u16, url: &str, headless: bool) -> Result<(), String> {
    // Find CfT binary
    let home = std::env::var("HOME").unwrap_or_default();
    let cft_paths = vec![
        format!("{home}/.flutter-skill/chrome-for-testing/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"),
        format!("{home}/.flutter-skill/chrome-for-testing/chrome-mac-x64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"),
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome".to_string(),
    ];

    let chrome_path = cft_paths.iter().find(|p| std::path::Path::new(p).exists())
        .ok_or("No Chrome binary found")?;

    // macOS: remove quarantine attribute (prevents --remote-debugging-port from silently failing)
    if cfg!(target_os = "macos") {
        if let Some(app_idx) = chrome_path.find(".app/") {
            let app_bundle = &chrome_path[..app_idx + 4];
            let _ = std::process::Command::new("xattr").args(["-cr", app_bundle]).output();
        }
    }

    let profile_dir = format!("{home}/.flutter-skill/chrome-profile");
    std::fs::create_dir_all(&profile_dir).ok();

    // Remove stale lock files
    let _ = std::fs::remove_file(format!("{profile_dir}/SingletonLock"));
    let _ = std::fs::remove_file(format!("{profile_dir}/SingletonSocket"));

    let mut args = vec![
        format!("--remote-debugging-port={port}"),
        "--remote-allow-origins=*".to_string(),
        "--no-first-run".to_string(),
        "--no-default-browser-check".to_string(),
        format!("--user-data-dir={profile_dir}"),
        "--disable-background-timer-throttling".to_string(),
        "--disable-backgrounding-occluded-windows".to_string(),
        "--disable-renderer-backgrounding".to_string(),
    ];
    if headless {
        args.push("--headless=new".to_string());
    }
    args.push(url.to_string());

    eprintln!("🚀 Launching Chrome on port {port}...");
    std::process::Command::new(chrome_path)
        .args(&args)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to start Chrome: {e}"))?;

    // Wait for CDP to be ready (raw TCP check)
    for i in 0..30 {
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        if let Ok(_) = tokio::net::TcpStream::connect(format!("127.0.0.1:{port}")).await {
            eprintln!("✅ Chrome ready in {}ms", (i + 1) * 500);
            return Ok(());
        }
    }
    Err("Chrome started but CDP port not responding after 15s".into())
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();

    let mut cdp_port: u16 = 9222;
    let mut server_port: u16 = 4000;
    let mut connect_all = false;
    let mut launch_chrome = false;
    let mut launch_url = String::from("about:blank");
    let mut headless = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--cdp-port" | "-c" => {
                i += 1;
                cdp_port = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(9222);
            }
            "--port" | "-p" => {
                i += 1;
                server_port = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(4000);
            }
            "--connect-all" => connect_all = true,
            "--launch" => launch_chrome = true,
            "--headless" => headless = true,
            "--url" => {
                i += 1;
                if let Some(u) = args.get(i) {
                    launch_url = u.clone();
                    launch_chrome = true;
                }
            }
            "--help" | "-h" => {
                eprintln!("fs-cdp — High-performance CDP browser engine");
                eprintln!();
                eprintln!("Usage: fs-cdp [OPTIONS]");
                eprintln!();
                eprintln!("Options:");
                eprintln!("  -c, --cdp-port <PORT>   Chrome CDP port [default: 9222]");
                eprintln!("  -p, --port <PORT>        API server port [default: 4000]");
                eprintln!("  --launch                 Auto-launch Chrome for Testing");
                eprintln!("  --url <URL>              URL to open (implies --launch)");
                eprintln!("  --headless               Launch Chrome in headless mode");
                eprintln!("  --connect-all            Pre-connect to all tabs on startup");
                eprintln!("  -h, --help               Show this help");
                return;
            }
            other => {
                // Positional arg = URL
                if !other.starts_with('-') {
                    launch_url = other.to_string();
                    launch_chrome = true;
                }
            }
        }
        i += 1;
    }

    // Launch Chrome if requested
    if launch_chrome {
        if let Err(e) = launch_cft(cdp_port, &launch_url, headless).await {
            eprintln!("❌ Failed to launch Chrome: {e}");
            std::process::exit(1);
        }
    }

    let pool = Arc::new(ConnectionPool::new(cdp_port));

    // Discover tabs (retry a few times if Chrome is still starting)
    let mut tabs_found = false;
    for attempt in 0..10 {
        match pool.discover_tabs().await {
            Ok(tabs) if !tabs.is_empty() => {
                eprintln!("📡 Found {} tabs on CDP port {cdp_port}", tabs.len());
                for tab in &tabs {
                    let url = if tab.url.len() > 60 {
                        format!("{}...", &tab.url[..57])
                    } else {
                        tab.url.clone()
                    };
                    eprintln!("   📄 {} — {}", tab.id.get(..8).unwrap_or(&tab.id), url);
                }
                tabs_found = true;
                break;
            }
            _ => {
                if attempt < 9 {
                    tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                }
            }
        }
    }
    if !tabs_found {
        eprintln!("❌ Cannot connect to Chrome on port {cdp_port}");
        eprintln!("   Make sure Chrome is running with --remote-debugging-port={cdp_port}");
        std::process::exit(1);
    }

    // Pre-connect to all tabs if requested
    if connect_all {
        let start = std::time::Instant::now();
        match pool.connect_all().await {
            Ok(n) => {
                eprintln!(
                    "✅ Connected to {n} tabs in {}ms",
                    start.elapsed().as_millis()
                );
            }
            Err(e) => eprintln!("⚠️ Error connecting: {e}"),
        }
    }

    // Start HTTP server
    if let Err(e) = server::start_http(pool, server_port).await {
        eprintln!("❌ Server error: {e}");
        std::process::exit(1);
    }
}
