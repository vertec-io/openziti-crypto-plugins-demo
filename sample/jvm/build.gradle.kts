plugins {
    kotlin("jvm") version "2.3.10"
    id("com.gradleup.shadow") version "9.0.0-beta12"
}

val variant: String = project.findProperty("variant") as? String ?: "stock"
val sdkVersion: String = project.findProperty("sdkVersion") as? String ?: "0.33.0"

repositories {
    mavenLocal()
    mavenCentral()
}

dependencies {
    implementation("org.openziti:ziti:$sdkVersion")
}

kotlin {
    jvmToolchain(21)
}

tasks.jar { enabled = false }

val manifestAttrs = mapOf(
    "Built-By" to "harness-ci",
    "Implementation-Title" to "openziti-cipher-interop-harness",
    "Implementation-Vendor" to "OpenZiti Cipher Interop Harness"
)

tasks.register<com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar>("clientJar") {
    archiveBaseName.set("$variant-client")
    archiveVersion.set("")
    archiveClassifier.set("")
    manifest { attributes(manifestAttrs + ("Main-Class" to "ClientKt")) }
    from(sourceSets.main.get().output)
    configurations = listOf(project.configurations.runtimeClasspath.get())
    mergeServiceFiles()
}

tasks.register<com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar>("hostJar") {
    archiveBaseName.set("$variant-host")
    archiveVersion.set("")
    archiveClassifier.set("")
    manifest { attributes(manifestAttrs + ("Main-Class" to "HostKt")) }
    from(sourceSets.main.get().output)
    configurations = listOf(project.configurations.runtimeClasspath.get())
    mergeServiceFiles()
}

tasks.named("build") {
    dependsOn("clientJar", "hostJar")
}
