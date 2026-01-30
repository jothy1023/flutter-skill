package com.aidashboad.flutterskill

import com.intellij.openapi.project.Project
import com.intellij.openapi.startup.ProjectActivity

class FlutterSkillStartupActivity : ProjectActivity {
    override suspend fun execute(project: Project) {
        val service = FlutterSkillService.getInstance(project)
        service.initialize()
    }
}
