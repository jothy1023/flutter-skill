import org.jetbrains.compose.desktop.application.dsl.TargetFormat

plugins {
    kotlin("jvm") version "1.9.22"
    id("org.jetbrains.compose") version "1.5.12"
    kotlin("plugin.serialization") version "1.9.22"
}

group = "com.flutterskill.testapp"
version = "1.0.0"

dependencies {
    implementation(compose.desktop.currentOs)

    // Ktor for WebSocket + HTTP server
    implementation("io.ktor:ktor-server-core:2.3.7")
    implementation("io.ktor:ktor-server-cio:2.3.7")
    implementation("io.ktor:ktor-server-websockets:2.3.7")
    implementation("io.ktor:ktor-server-content-negotiation:2.3.7")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
}

compose.desktop {
    application {
        mainClass = "MainKt"
    }
}
