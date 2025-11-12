plugins {
    id("maven-publish")
    id("signing")
}

group = "shipth.is"
// Accept version as a parameter, default to 0.0.1 if not provided
version = project.findProperty("version") as String? ?: "0.0.1"

// Accept godot version as a parameter, default to 4.4.1 if not provided
val godotVersion = project.findProperty("godotVersion") as String? ?: "4.4.1"
val releaseAARfile = file("godot-${godotVersion}/bin/godot-lib.template_release.aar")
var debugAARfile = file("godot-${godotVersion}/bin/godot-lib.template_debug.aar")

publishing {
    publications {
        create<MavenPublication>("godotLib") {
            artifactId = "godot-lib-v${godotVersion.replace(".", "-")}"
            
            // Add the AAR file as an artifact
            artifact(releaseAARfile) {
                classifier = "template-release"
                extension = "aar"
            }
            artifact(debugAARfile) {
                classifier = "template-debug"
                extension = "aar"
            }
            
            // Create a minimal POM
            pom {
                name.set("Godot Android Library")
                description.set("Patched Godot Android library with filesystem-based asset access")
                url.set("https://github.com/shipth-is/godroid-builder")
                
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                
                developers {
                    developer {
                        id.set("madebydavid")
                        name.set("David Sutherland")
                        email.set("sutherland.dave@gmail.com")
                    }
                }
                
                scm {
                    connection.set("scm:git:git://github.com/shipth-is/godroid-builder.git")
                    developerConnection.set("scm:git:ssh://github.com:shipth-is/godroid-builder.git")
                    url.set("https://github.com/shipth-is/godroid-builder")
                }
            }
        }
    }
    
    repositories {
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/shipth-is/godroid-builder")
            credentials {
                username = project.findProperty("gpr.user") as String? ?: System.getenv("GITHUB_ACTOR")
                password = project.findProperty("gpr.key") as String? ?: System.getenv("GITHUB_TOKEN")
            }
        }
    }
}

// Ensure the AAR file exists before publishing
tasks.named("publish") {
    dependsOn(":buildAar")
}

tasks.register("buildAar") {
    doLast {
        if (!releaseAARfile.exists() {
            throw GradleException("AAR file not found: ${releaseAARfile.absolutePath}. Run ./build-aar.sh first.")
        }
        if (!debugAARfile.exists()) {
            throw GradleException("AAR file not found: ${debugAARfile.absolutePath}. Run ./build-aar.sh first.")
        }
    }
}

// Signing configuration (optional, for verified packages)
signing {
    val signingKey = project.findProperty("signing.keyId") as String?
    val signingPassword = project.findProperty("signing.password") as String?
    val signingSecretKeyRingFile = project.findProperty("signing.secretKeyRingFile") as String?
    
    if (signingKey != null) {
        useInMemoryPgpKeys(signingKey, signingPassword, signingSecretKeyRingFile)
        sign(publishing.publications["godotLib"])
    }
}
