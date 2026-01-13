# Godroid Builder

Patched and namespaced builds of the Android Godot library.

This repo creates namespaced versions of godot-lib.template_release.aar with custom patches included.

## Namespaces

The Java classes for the 3.x and 4.0-4.5 branches of godot are renamed to include the version number.

For example, a 3.x import becomes:

```java
import org.godotengine.godotv3_x.FullScreenGodotApp;
```

## Patches

Each branch has an "overlay" folder which is applied on-top of the clone from the main Godot repo. Each overlay includes patches for:

- Loading game assets from a hard-coded path inside `/data/user/0/com.shipthis.go/files/assets`
- Adjustments to work with the [16 KB Google Play compatibility requirement](https://developer.android.com/guide/practices/page-sizes).
- Forwarding of all log messages to a WebSocket handler.
- Adaptations to work with [Play Feature Delivery](https://developer.android.com/guide/playcore/feature-delivery).
- Adaptations to work with the namespace.

## Using

Add the ShipThis Godot library to your module's `build.gradle.kts`:

```kotlin
val godotVersion = "4.5"
val godotVersionDash = godotVersion.replace('.', '-')
val buildType = "debug" // or "release"

dependencies {
    implementation(
        "shipth.is:godot-lib-v$godotVersionDash:+:template-$buildType@aar"
    )
}
````

### Notes

* `godotVersion` must match the Godot engine version your project targets.
* `buildType` should align with your app’s build variant (`debug` or `release`).
* The `+` version selector always resolves to the latest compatible build for that Godot version.

## License

MIT