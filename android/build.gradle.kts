/**
 * 目的：根專案的 Gradle 建置配置 (Root Project Build Configuration)
 * 作用：定義全域的專案設定，包括所有子模組共用的儲存庫來源、自定義建置目錄結構，以及全域的清理 (clean) 任務。
 * 格式與用法：使用 Kotlin DSL (Gradle) 編寫。通常不需要頻繁修改，除非需要調整全域編譯選項或儲存庫。
 */

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
